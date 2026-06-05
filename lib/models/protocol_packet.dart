import 'dart:convert';

class ProtocolPacket {
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  ProtocolPacket({
    required this.type,
    required this.payload,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String encode() {
    return '${jsonEncode(toJson())}\n';
  }

  factory ProtocolPacket.fromJson(Map<String, dynamic> json) {
    return ProtocolPacket(
      type: json['type'],
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  factory ProtocolPacket.fromLine(String line) {
    final data = jsonDecode(line);
    return ProtocolPacket.fromJson(data);
  }

  factory ProtocolPacket.sessionHello({
    required String sessionId,
    required String deviceId,
    required String deviceName,
    required String fingerprint,
    required int tcpPort,
    required Map<String, dynamic> publicKey,
  }) {
    return ProtocolPacket(
      type: 'SESSION_HELLO',
      payload: {
        'sessionId': sessionId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'fingerprint': fingerprint,
        'tcpPort': tcpPort,
        'publicKey': publicKey,
      },
    );
  }

  factory ProtocolPacket.sessionOk({
    required String sessionId,
    required String deviceId,
    required String deviceName,
    required String fingerprint,
    required int tcpPort,
    required Map<String, dynamic> publicKey,
  }) {
    return ProtocolPacket(
      type: 'SESSION_OK',
      payload: {
        'sessionId': sessionId,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'fingerprint': fingerprint,
        'tcpPort': tcpPort,
        'publicKey': publicKey,
      },
    );
  }

  factory ProtocolPacket.sessionReject({required String reason}) {
    return ProtocolPacket(type: 'SESSION_REJECT', payload: {'reason': reason});
  }

  factory ProtocolPacket.sessionKey({required String encryptedSessionKey}) {
    return ProtocolPacket(
      type: 'SESSION_KEY',
      payload: {'encryptedSessionKey': encryptedSessionKey},
    );
  }

  factory ProtocolPacket.chatMessage({required String text}) {
    return ProtocolPacket(type: 'CHAT_MESSAGE', payload: {'text': text});
  }

  factory ProtocolPacket.encryptedChatMessage({
    required Map<String, dynamic> encryptedPayload,
  }) {
    return ProtocolPacket(
      type: 'ENCRYPTED_CHAT_MESSAGE',
      payload: encryptedPayload,
    );
  }

  factory ProtocolPacket.encryptedFile({
    required String fileName,
    required int originalSize,
    required Map<String, dynamic> encryptedPayload,
  }) {
    return ProtocolPacket(
      type: 'ENCRYPTED_FILE',
      payload: {
        'fileName': fileName,
        'originalSize': originalSize,
        'encryptedPayload': encryptedPayload,
      },
    );
  }

  factory ProtocolPacket.disconnect() {
    return ProtocolPacket(type: 'DISCONNECT', payload: {});
  }

  factory ProtocolPacket.error({required String message}) {
    return ProtocolPacket(type: 'ERROR', payload: {'message': message});
  }
}
