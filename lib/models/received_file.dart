class ReceivedFile {
  final String fileName;
  final int size;
  final List<int> bytes;
  final DateTime receivedAt;

  const ReceivedFile({
    required this.fileName,
    required this.size,
    required this.bytes,
    required this.receivedAt,
  });
}
