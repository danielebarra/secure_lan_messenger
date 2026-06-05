class ConnectionRequest {
  final String sessionId;
  final String fromDeviceId;
  final String fromDeviceName;
  final String fromIp;
  final int fromTcpPort;
  final String fromFingerprint;
  final String securityCode;

  const ConnectionRequest({
    required this.sessionId,
    required this.fromDeviceId,
    required this.fromDeviceName,
    required this.fromIp,
    required this.fromTcpPort,
    required this.fromFingerprint,
    required this.securityCode,
  });
}
