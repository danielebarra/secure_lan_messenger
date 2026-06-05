import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:secure_lan_messenger/models/peer_device.dart';
import 'package:secure_lan_messenger/models/protocol_packet.dart';
import 'package:secure_lan_messenger/services/crypto_service.dart';

class NetworkService {
  static const int tcpPort = 5000;

  final String deviceId;
  final String deviceName;
  final String fingerprint;
  final CryptoService cryptoService;

  ServerSocket? _serverSocket;
  Socket? _activeSocket;

  final Map<String, String> _allowedSessions = {};

  PeerDevice? _connectedPeer;

  NetworkService({
    required this.deviceId,
    required this.deviceName,
    required this.fingerprint,
    required this.cryptoService,
  });

  bool get isConnected => _activeSocket != null;

  final StreamController<PeerDevice?> _connectedPeerController =
      StreamController<PeerDevice?>.broadcast();

  Stream<PeerDevice?> get connectedPeerStream =>
      _connectedPeerController.stream;

  PeerDevice? get connectedPeer => _connectedPeer;

  void _setConnectedPeer(PeerDevice? peer) {
    _connectedPeer = peer;
    _connectedPeerController.add(peer);
  }

  final StreamController<String> _incomingMessagesController =
      StreamController<String>.broadcast();

  Stream<String> get incomingMessages => _incomingMessagesController.stream;

  Future<void> startServer() async {
    if (_serverSocket != null) return;

    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
    print('TCP Server in ascolto sulla port $tcpPort');

    _serverSocket!.listen(_handleIncomingConnection);
  }

  void allowSession({
    required String sessionId,
    required String remoteDeviceId,
  }) {
    _allowedSessions[sessionId] = remoteDeviceId;
    print('Sessione autorizzata: $sessionId per $remoteDeviceId');
  }

  void _handleIncomingConnection(Socket socket, {PeerDevice? peer}) {
    print(
      'Connessione TCP ricevuta da ${socket.remoteAddress.address}:${socket.remotePort}',
    );

    _activeSocket = socket;

    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) async {
            try {
              final packet = ProtocolPacket.fromLine(line);

              switch (packet.type) {
                case 'SESSION_HELLO':
                  _handleSessionHello(socket, packet);
                  break;

                case 'SESSION_OK':
                  await _handleSessionOk(socket, packet, peer: peer);

                  print('SESSION_OK ricevuto');
                  break;

                case 'SESSION_REJECT':
                  print('Sessione rifiutata');
                  _clearConnection(destroySocket: true);
                  break;

                case 'SESSION_KEY':
                  _handleSessionKey(packet);
                  break;

                case 'CHAT_MESSAGE':
                  final text = packet.payload['text'];

                  if (text is String) {
                    _incomingMessagesController.add(text);
                  }
                  break;

                case 'ENCRYPTED_CHAT_MESSAGE':
                  _handleEncryptedChatMessage(packet);
                  break;

                case 'DISCONNECT':
                  _clearConnection(destroySocket: true);
                  break;

                case 'ERROR':
                  print('Errore remoto: ${packet.payload['message']}');
                  break;

                default:
                  throw Exception(
                    '_handleIncomingConnection: default chiamato',
                  );
              }
            } catch (e) {
              print('Messaggio TCP non valido: $e');
              _clearConnection(destroySocket: true);
            }
          },
          onError: (e) {
            print('Errore socket: $e');
            _clearConnection(destroySocket: true);
          },
          onDone: () {
            print('Socket chiusa');
            _clearConnection();
          },
        );
  }

  void _handleSessionHello(Socket socket, ProtocolPacket packet) {
    final data = packet.payload;

    final sessionId = data['sessionId'];
    final remoteDeviceId = data['deviceId'];

    final expectedDeviceId = _allowedSessions[sessionId];

    if (expectedDeviceId == null || expectedDeviceId != remoteDeviceId) {
      final reject = ProtocolPacket.sessionReject(
        reason: 'Sessione non autorizzata',
      );

      socket.write(reject.encode());
      socket.destroy();

      print("SESSION_HELLO rifiutato");
      return;
    }

    _activeSocket = socket;

    final response = ProtocolPacket.sessionOk(
      sessionId: sessionId,
      deviceId: deviceId,
      deviceName: deviceName,
      fingerprint: fingerprint,
      tcpPort: tcpPort,
      publicKey: cryptoService.exportPublicKey(),
    );

    final peer = PeerDevice(
      deviceId: data['deviceId'],
      name: data['deviceName'],
      ip: socket.remoteAddress.address,
      port: data['tcpPort'],
      fingerprint: data['fingerprint'],
    );

    _setConnectedPeer(peer);

    socket.write(response.encode());

    print('SESSION_OK inviato. Connessione TCP stabilita.');
  }

  Future<void> _handleSessionOk(
    Socket socket,
    ProtocolPacket packet, {
    PeerDevice? peer,
  }) async {
    _activeSocket = socket;

    if (peer != null) {
      _setConnectedPeer(peer);
    }

    final remotePublicKeyJson = Map<String, dynamic>.from(
      packet.payload['publicKey'],
    );

    final remotePublicKey = cryptoService.importPublicKey(remotePublicKeyJson);

    await cryptoService.generateSessionKey();

    final sessionKeyBytes = await cryptoService.exportSessionKeyBytes();

    final encryptedSessionKey = cryptoService.rsaEncryptSessionKey(
      receiverPublicKey: remotePublicKey,
      sessionKeyBytes: sessionKeyBytes,
    );

    final sessionKeyPacket = ProtocolPacket.sessionKey(
      encryptedSessionKey: encryptedSessionKey,
    );

    socket.write(sessionKeyPacket.encode());

    print('SESSION_KEY inviata');
  }

  void _handleSessionKey(ProtocolPacket packet) {
    final encryptedSessionKey = packet.payload['encryptedSessionKey'];

    if (encryptedSessionKey is! String) {
      print('SESSION_KEY non valida');
      return;
    }

    final sessionKeyBytes = cryptoService.rsaDecryptSessionKey(
      encryptedSessionKey,
    );

    cryptoService.setSessionKeyFromBytes(sessionKeyBytes);

    print('SESSION_KEY ricevuta');
  }

  Future<void> _handleEncryptedChatMessage(ProtocolPacket packet) async {
    try {
      final encryptedPayload = EncryptedPayload.fromJson(packet.payload);

      final clearText = await cryptoService.decryptText(encryptedPayload);

      _incomingMessagesController.add(clearText);
    } catch (e) {
      print('Errore decifratura messaggio: $e');
    }
  }

  Future<bool> connectToPeer({
    required PeerDevice peer,
    required String sessionId,
  }) async {
    try {
      final socket = await Socket.connect(
        peer.ip,
        peer.port,
        timeout: const Duration(seconds: 4),
      );

      _handleIncomingConnection(socket, peer: peer);

      final request = ProtocolPacket.sessionHello(
        sessionId: sessionId,
        deviceId: deviceId,
        deviceName: deviceName,
        fingerprint: fingerprint,
        tcpPort: tcpPort,
        publicKey: cryptoService.exportPublicKey(),
      );

      socket.write(request.encode());

      return true;
    } catch (e) {
      print('Errore connessione TCP: $e');
      return false;
    }
  }

  void disconnectPeer() {
    final socket = _activeSocket;

    if (socket == null) {
      _clearConnection();
      return;
    }

    try {
      final packet = ProtocolPacket.disconnect();
      socket.write(packet.encode());
    } catch (e) {
      print('Errore invio DISCONNECT: $e');
    }

    _clearConnection(destroySocket: true);
  }

  Future<void> sendTextMessage(String text) async {
    final socket = _activeSocket;

    if (socket == null) {
      throw Exception("Nessuna connessione TCP attiva");
    }

    if (!cryptoService.hasSessionKey) {
      throw Exception("cryptoService non ha SessionKey AES");
    }

    final encrypted = await cryptoService.encryptText(text);

    final packet = ProtocolPacket.encryptedChatMessage(
      encryptedPayload: encrypted.toJson(),
    );

    socket.write(packet.encode());
  }

  void _clearConnection({bool destroySocket = false}) {
    final socket = _activeSocket;

    _activeSocket = null;
    _setConnectedPeer(null);
    cryptoService.clearSessionKey();

    if (destroySocket) {
      socket?.destroy();
    }
  }

  void dispose() {
    _activeSocket?.destroy();
    _activeSocket = null;

    _serverSocket?.close();
    _serverSocket = null;

    _allowedSessions.clear();

    _incomingMessagesController.close();
    _connectedPeerController.close();
  }
}
