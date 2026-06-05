import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:secure_lan_messenger/models/connection_status.dart';
import 'package:secure_lan_messenger/models/peer_device.dart';
import 'package:secure_lan_messenger/models/protocol_packet.dart';
import 'package:secure_lan_messenger/models/received_file.dart';
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

  final StreamController<ReceivedFile> _incomingFilesController =
      StreamController<ReceivedFile>.broadcast();

  Stream<ReceivedFile> get incomingFiles => _incomingFilesController.stream;

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnect;

  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  ConnectionStatus get connectionStatus => _connectionStatus;

  void _setConnectionStatus(ConnectionStatus status) {
    if (_connectionStatus == status) return;

    _connectionStatus = status;
    _connectionStatusController.add(status);

    print('Stato connessione: $status');
  }

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

  void _handleIncomingConnection(
    Socket socket, {
    PeerDevice? peer,
    Completer<bool>? connectionCompleter,
  }) {
    print(
      'Connessione TCP ricevuta da ${socket.remoteAddress.address}:${socket.remotePort}',
    );

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

                  if (connectionCompleter != null &&
                      !connectionCompleter.isCompleted) {
                    connectionCompleter.complete(true);
                  }

                  print('SESSION_OK ricevuto');
                  break;

                case 'SESSION_REJECT':
                  print('Sessione rifiutata');

                  if (connectionCompleter != null &&
                      !connectionCompleter.isCompleted) {
                    connectionCompleter.complete(false);
                  }

                  _clearConnection(
                    destroySocket: true,
                    socketToDestroy: socket,
                  );
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
                  await _handleEncryptedChatMessage(packet);
                  break;

                case 'ENCRYPTED_FILE':
                  await _handleEncryptedFile(packet);
                  break;

                case 'DISCONNECT':
                  _clearConnection(
                    destroySocket: true,
                    socketToDestroy: socket,
                  );
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

              if (connectionCompleter != null &&
                  !connectionCompleter.isCompleted) {
                connectionCompleter.complete(false);
              }

              _clearConnection(destroySocket: true, socketToDestroy: socket);
            }
          },
          onError: (e) {
            print('Errore socket: $e');

            if (connectionCompleter != null &&
                !connectionCompleter.isCompleted) {
              connectionCompleter.complete(false);
            }

            _clearConnection(destroySocket: true, socketToDestroy: socket);
          },
          onDone: () {
            print('Socket chiusa');

            if (connectionCompleter != null &&
                !connectionCompleter.isCompleted) {
              connectionCompleter.complete(false);
            }

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
      _clearConnection(destroySocket: true, socketToDestroy: socket);

      print("SESSION_HELLO rifiutato");
      return;
    }

    _activeSocket = socket;

    _setConnectionStatus(ConnectionStatus.tcpConnected);

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

    _setConnectionStatus(ConnectionStatus.tcpConnected);

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

    _setConnectionStatus(ConnectionStatus.secureReady);

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

    _setConnectionStatus(ConnectionStatus.secureReady);

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

  Future<void> _handleEncryptedFile(ProtocolPacket packet) async {
    try {
      final fileName = packet.payload['fileName'];
      final originalSize = packet.payload['originalSize'];
      final encryptedPayloadJson = packet.payload['encryptedPayload'];

      if (fileName is! String || originalSize is! int) {
        throw Exception('Pacchetto file non valido');
      }

      final encryptedPayload = EncryptedPayload.fromJson(
        Map<String, dynamic>.from(encryptedPayloadJson),
      );

      final clearBytes = await cryptoService.decryptBytes(encryptedPayload);

      _incomingFilesController.add(
        ReceivedFile(
          fileName: fileName,
          size: clearBytes.length,
          bytes: clearBytes,
          receivedAt: DateTime.now(),
        ),
      );

      print('File ricevuto in memoria: $fileName');
    } catch (e) {
      print('Errore ricezione file: $e');
    }
  }

  Future<void> sendFile({
    required String filePath,
    required String fileName,
  }) async {
    final socket = _activeSocket;

    if (socket == null) {
      throw Exception('Nessuna connessione TCP attiva');
    }

    if (_connectionStatus != ConnectionStatus.secureReady) {
      throw Exception('Sessione sicura non ancora pronta');
    }

    if (!cryptoService.hasSessionKey) {
      throw Exception('Session key AES non pronta');
    }

    final file = File(filePath);
    final bytes = await file.readAsBytes();

    final encrypted = await cryptoService.encryptBytes(bytes);

    final packet = ProtocolPacket.encryptedFile(
      fileName: fileName,
      originalSize: bytes.length,
      encryptedPayload: encrypted.toJson(),
    );

    socket.write(packet.encode());

    print('File inviato: $fileName');
  }

  Future<bool> connectToPeer({
    required PeerDevice peer,
    required String sessionId,
  }) async {
    try {
      _setConnectionStatus(ConnectionStatus.connecting);

      final socket = await Socket.connect(
        peer.ip,
        peer.port,
        timeout: const Duration(seconds: 4),
      );

      final connectionCompleter = Completer<bool>();

      _handleIncomingConnection(
        socket,
        peer: peer,
        connectionCompleter: connectionCompleter,
      );

      final request = ProtocolPacket.sessionHello(
        sessionId: sessionId,
        deviceId: deviceId,
        deviceName: deviceName,
        fingerprint: fingerprint,
        tcpPort: tcpPort,
        publicKey: cryptoService.exportPublicKey(),
      );

      socket.write(request.encode());

      return await connectionCompleter.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          _clearConnection(destroySocket: true, socketToDestroy: socket);
          return false;
        },
      );
    } catch (e) {
      print('Errore connessione TCP: $e');
      _setConnectionStatus(ConnectionStatus.disconnect);
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

    _clearConnection(destroySocket: true, socketToDestroy: socket);
  }

  Future<void> sendTextMessage(String text) async {
    final socket = _activeSocket;

    if (socket == null) {
      throw Exception("Nessuna connessione TCP attiva");
    }

    if (_connectionStatus != ConnectionStatus.secureReady) {
      throw Exception("Secure Session non ancora pronta");
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

  void _clearConnection({bool destroySocket = false, Socket? socketToDestroy}) {
    final socket = socketToDestroy ?? _activeSocket;

    _activeSocket = null;
    _setConnectedPeer(null);
    _setConnectionStatus(ConnectionStatus.disconnect);
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
    _connectionStatusController.close();
    _incomingFilesController.close();
  }
}
