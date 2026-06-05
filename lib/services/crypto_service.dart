import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' as pc;

class EncryptedPayload {
  final String nonce;
  final String ciphertext;
  final String mac;

  EncryptedPayload({
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  Map<String, dynamic> toJson() {
    return {'nonce': nonce, 'ciphertext': ciphertext, 'mac': mac};
  }

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      nonce: json['nonce'],
      ciphertext: json['ciphertext'],
      mac: json['mac'],
    );
  }
}

class CryptoService {
  final AesGcm _aesGcm = AesGcm.with256bits();

  SecretKey? _sessionKey;

  late pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> _rsaKeyPair;

  pc.RSAPublicKey get publicKey => _rsaKeyPair.publicKey as pc.RSAPublicKey;

  pc.RSAPrivateKey get privateKey => _rsaKeyPair.privateKey as pc.RSAPrivateKey;

  bool get hasSessionKey => _sessionKey != null;

  void generateRsaKeyPair() {
    final keyGenerator = pc.RSAKeyGenerator();

    keyGenerator.init(
      pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        _secureRandom(),
      ),
    );

    _rsaKeyPair = keyGenerator.generateKeyPair();
  }

  pc.SecureRandom _secureRandom() {
    final secureRandom = pc.FortunaRandom();
    final random = Random.secure();

    final seed = Uint8List(32);
    for (int i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }

    secureRandom.seed(pc.KeyParameter(seed));
    return secureRandom;
  }

  Map<String, dynamic> exportPublicKey() {
    return {
      'modulus': publicKey.modulus.toString(),
      'exponent': publicKey.exponent.toString(),
    };
  }

  pc.RSAPublicKey importPublicKey(Map<String, dynamic> json) {
    return pc.RSAPublicKey(
      BigInt.parse(json['modulus']),
      BigInt.parse(json['exponent']),
    );
  }

  String get publicKeyFingerprint {
    final keyData = '${publicKey.modulus}:${publicKey.exponent}';
    final digest = sha256.convert(utf8.encode(keyData)).toString();

    return digest
        .substring(0, 24)
        .toUpperCase()
        .replaceAllMapped(RegExp(r'.{2}'), (match) => '${match.group(0)}')
        .replaceAll(RegExp(r':$'), '');
  }

  String rsaEncryptSessionKey({
    required pc.RSAPublicKey receiverPublicKey,
    required List<int> sessionKeyBytes,
  }) {
    final cipher = pc.OAEPEncoding(pc.RSAEngine());

    cipher.init(
      true,
      pc.PublicKeyParameter<pc.RSAPublicKey>(receiverPublicKey),
    );

    final encrypted = cipher.process(Uint8List.fromList(sessionKeyBytes));

    return base64Encode(encrypted);
  }

  List<int> rsaDecryptSessionKey(String encryptedSessionKey) {
    final cipher = pc.OAEPEncoding(pc.RSAEngine());

    cipher.init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));

    final encryptedBytes = base64Decode(encryptedSessionKey);
    final decrypted = cipher.process(Uint8List.fromList(encryptedBytes));

    return decrypted;
  }

  Future<void> generateSessionKey() async {
    _sessionKey = await _aesGcm.newSecretKey();
  }

  void setSessionKeyFromBytes(List<int> bytes) {
    _sessionKey = SecretKey(bytes);
  }

  Future<List<int>> exportSessionKeyBytes() async {
    final key = _sessionKey;

    if (key == null) {
      throw Exception('Session key non inizializzata');
    }

    return key.extractBytes();
  }

  Future<EncryptedPayload> encryptText(String text) async {
    final key = _sessionKey;

    if (key == null) {
      throw Exception('Session key non inizializzata');
    }

    final plainBytes = utf8.encode(text);

    final secretBox = await _aesGcm.encrypt(plainBytes, secretKey: key);

    return EncryptedPayload(
      nonce: base64Encode(secretBox.nonce),
      ciphertext: base64Encode(secretBox.cipherText),
      mac: base64Encode(secretBox.mac.bytes),
    );
  }

  Future<String> decryptText(EncryptedPayload payload) async {
    final key = _sessionKey;

    if (key == null) {
      throw Exception('Session key non inizializzata');
    }

    final secretBox = SecretBox(
      base64Decode(payload.ciphertext),
      nonce: base64Decode(payload.nonce),
      mac: Mac(base64Decode(payload.mac)),
    );

    final clearBytes = await _aesGcm.decrypt(secretBox, secretKey: key);

    return utf8.decode(clearBytes);
  }

  void clearSessionKey() {
    _sessionKey = null;
  }
}
