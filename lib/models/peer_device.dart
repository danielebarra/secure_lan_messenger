class PeerDevice {
  final String deviceId;
  final String name;
  final String ip;
  final int port;
  final String fingerprint;

  const PeerDevice({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.port,
    required this.fingerprint,
  });
}
