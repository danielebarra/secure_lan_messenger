import 'dart:io';

import 'package:secure_lan_messenger/services/chat_service.dart';
import 'package:secure_lan_messenger/services/crypto_service.dart';
import 'package:secure_lan_messenger/services/discovery_service.dart';
import 'package:secure_lan_messenger/services/network_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AppServices {
  static late final DiscoveryService discoveryService;
  static late final NetworkService networkService;
  static late final ChatService chatService;
  static late final CryptoService cryptoService;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    final deviceName = Platform.localHostname;

    cryptoService = CryptoService();
    cryptoService.generateRsaKeyPair();

    final fingerprint = cryptoService.publicKeyFingerprint;

    discoveryService = DiscoveryService(
      deviceName: deviceName,
      deviceId: deviceId,
      fingerprint: fingerprint,
    );

    networkService = NetworkService(
      deviceId: deviceId,
      deviceName: deviceName,
      fingerprint: fingerprint,
      cryptoService: cryptoService,
    );

    chatService = ChatService(networkService: networkService);

    await discoveryService.startResponder();
    await networkService.startServer();
    chatService.startListening();
  }
}
