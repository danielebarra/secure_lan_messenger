import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:secure_lan_messenger/models/connection_request.dart';
import 'package:secure_lan_messenger/models/peer_device.dart';
import 'package:uuid/uuid.dart';

class DiscoveryService {
  static const int discoveryPort = 45678;
  static const int tcpPort = 5000;

  RawDatagramSocket? _responderSocket;

  final String deviceName;
  final String deviceId;
  final String fingerprint;

  DiscoveryService({
    required this.deviceName,
    required this.deviceId,
    required this.fingerprint,
  });

  final StreamController<ConnectionRequest> _incomingRequestsController =
      StreamController<ConnectionRequest>.broadcast();

  Stream<ConnectionRequest> get incomingRequests =>
      _incomingRequestsController.stream;

  final StreamController<String> _connectionAcceptedController =
      StreamController<String>.broadcast();

  Stream<String> get connectionAccepted => _connectionAcceptedController.stream;

  final StreamController<String> _connectionRejectedController =
      StreamController<String>.broadcast();

  Stream<String> get connectionRejected => _connectionRejectedController.stream;

  final StreamController<String> _connectionCancelledController =
      StreamController<String>.broadcast();

  Stream<String> get connectionCancelled =>
      _connectionCancelledController.stream;

  final StreamController<bool> _isResponderOnlineController =
      StreamController<bool>.broadcast();
  bool _responderOnline = false;

  Stream<bool> get isResponderOnline => _isResponderOnlineController.stream;
  bool get responderOnline => _responderOnline;

  void _setResponderOnline(bool value) {
    if (_responderOnline == value) return;
    _responderOnline = value;
    _isResponderOnlineController.add(value);
  }

  String _buildSecurityCode({
    required String sessionId,
    required String fingerprintA,
    required String fingerprintB,
  }) {
    final fingerprints = [fingerprintA, fingerprintB]..sort();

    final input = '$sessionId:${fingerprints[0]}:${fingerprints[1]}';
    final digest = sha256.convert(utf8.encode(input)).toString();

    final number = int.parse(digest.substring(0, 8), radix: 16);
    final code = (number % 1000000).toString().padLeft(6, '0');

    return '${code.substring(0, 3)}-${code.substring(3, 6)}';
  }

  Future<void> startResponder() async {
    if (_responderSocket != null) return;

    _responderSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      DiscoveryService.discoveryPort,
    );

    _setResponderOnline(true);
    _responderSocket!.broadcastEnabled = true;

    _responderSocket!.listen((event) {
      if (event != RawSocketEvent.read) return;

      final datagram = _responderSocket!.receive();
      if (datagram == null) return;

      final message = utf8.decode(datagram.data);

      final data = jsonDecode(message);

      switch (data['type']) {
        case 'DISCOVER_SECURE_LAN':
          _handleDiscoveryRequest(data, datagram);
          break;

        case 'CONNECTION_REQUEST':
          _handleConnectionRequest(data, datagram);
          break;

        case 'CONNECTION_ACCEPT':
          _connectionAcceptedController.add(data['sessionId']);
          break;

        case 'CONNECTION_REJECT':
          _connectionRejectedController.add(data['sessionId']);
          break;

        case 'CONNECTION_CANCEL':
          _connectionCancelledController.add(data['sessionId']);
          break;
      }
    });
  }

  void _handleDiscoveryRequest(dynamic data, Datagram datagram) {
    try {
      if (data['deviceId'] == deviceId) return;
      print(
        'DISCOVERY richiesta ricevuta da ${datagram.address.address}:${datagram.port}',
      );

      final response = {
        'type': 'DISCOVER_RESPONSE',
        'deviceName': deviceName,
        'deviceId': deviceId,
        'tcpPort': DiscoveryService.tcpPort,
        'fingerprint': fingerprint,
      };

      final bytes = utf8.encode(jsonEncode(response));

      print('Invio risposta discovery a ${datagram.address.address}');

      _responderSocket!.send(bytes, datagram.address, datagram.port);
    } catch (_) {
      print("messaggio non valido");
    }
  }

  void _handleConnectionRequest(dynamic data, Datagram datagram) {
    if (data['fromDeviceId'] == deviceId) return;

    final securityCode = _buildSecurityCode(
      sessionId: data['sessionId'],
      fingerprintA: data['fromFingerprint'],
      fingerprintB: fingerprint,
    );

    final request = ConnectionRequest(
      sessionId: data['sessionId'],
      fromDeviceId: data['fromDeviceId'],
      fromDeviceName: data['fromDeviceName'],
      fromIp: datagram.address.address,
      fromTcpPort: data['fromTcpPort'],
      fromFingerprint: data['fromFingerprint'],
      securityCode: securityCode,
    );

    _incomingRequestsController.add(request);
  }

  Future<Map<String, String>> sendConnectionRequest(PeerDevice peer) async {
    final sessionId = const Uuid().v4();

    final securityCode = _buildSecurityCode(
      sessionId: sessionId,
      fingerprintA: fingerprint,
      fingerprintB: peer.fingerprint,
    );

    final request = {
      'type': 'CONNECTION_REQUEST',
      'sessionId': sessionId,
      'fromDeviceId': deviceId,
      'fromDeviceName': deviceName,
      'fromTcpPort': DiscoveryService.tcpPort,
      'fromFingerprint': fingerprint,
    };

    final bytes = utf8.encode(jsonEncode(request));

    _responderSocket!.send(
      bytes,
      InternetAddress(peer.ip),
      DiscoveryService.discoveryPort,
    );

    return {'sessionId': sessionId, 'securityCode': securityCode};
  }

  void acceptConnection(ConnectionRequest request) {
    final response = {
      'type': 'CONNECTION_ACCEPT',
      'sessionId': request.sessionId,
      'fromDeviceId': deviceId,
      'fromDeviceName': deviceName,
      'fromTcpPort': DiscoveryService.tcpPort,
      'fromFingerprint': fingerprint,
    };

    final bytes = utf8.encode(jsonEncode(response));

    _responderSocket!.send(
      bytes,
      InternetAddress(request.fromIp),
      DiscoveryService.discoveryPort,
    );
  }

  void rejectConnection(ConnectionRequest request) {
    final response = {
      'type': 'CONNECTION_REJECT',
      'sessionId': request.sessionId,
    };

    final bytes = utf8.encode(jsonEncode(response));

    _responderSocket!.send(
      bytes,
      InternetAddress(request.fromIp),
      DiscoveryService.discoveryPort,
    );
  }

  void cancelConnectionRequest({
    required String sessionId,
    required PeerDevice peer,
  }) {
    final response = {
      'type': 'CONNECTION_CANCEL',
      'sessionId': sessionId,
      'fromDeviceId': deviceId,
      'fromDeviceName': deviceName,
    };

    final bytes = utf8.encode(jsonEncode(response));

    _responderSocket!.send(
      bytes,
      InternetAddress(peer.ip),
      DiscoveryService.discoveryPort,
    );
  }

  Future<List<PeerDevice>> scanDevices() async {
    print("Scan Devices");
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    socket.broadcastEnabled = true;

    final peers = <PeerDevice>[];
    final completer = Completer<List<PeerDevice>>();

    socket.listen((event) {
      if (event != RawSocketEvent.read) return;

      final datagram = socket.receive();
      if (datagram == null) return;

      try {
        final message = utf8.decode(datagram.data);
        final data = jsonDecode(message);

        if (data['type'] != 'DISCOVER_RESPONSE') return;
        if (data['deviceId'] == deviceId) return;

        print('Risposta ricevuta da ${datagram.address.address}');
        print(data);

        peers.add(
          PeerDevice(
            deviceId: data['deviceId'],
            name: data['deviceName'],
            ip: datagram.address.address,
            port: data['tcpPort'],
            fingerprint: data['fingerprint'],
          ),
        );
      } catch (_) {
        print("risposta non valida");
      }
    });

    final request = {'type': 'DISCOVER_SECURE_LAN', 'deviceId': deviceId};

    final bytes = utf8.encode(jsonEncode(request));

    socket.send(
      bytes,
      InternetAddress('255.255.255.255'),
      DiscoveryService.discoveryPort,
    );

    Timer(const Duration(seconds: 2), () {
      socket.close();
      completer.complete(peers);
    });

    return completer.future;
  }

  void stopResponder() {
    _responderSocket?.close();
    _responderSocket = null;
    _setResponderOnline(false);
  }

  void closeResponder() {
    _responderSocket?.close();
    _responderSocket = null;
    _setResponderOnline(false);

    _incomingRequestsController.close();
    _connectionAcceptedController.close();
    _connectionRejectedController.close();
    _connectionCancelledController.close();
    _isResponderOnlineController.close();
  }
}
