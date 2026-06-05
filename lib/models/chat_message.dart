enum ChatMessageType { text, file }

class ChatMessage {
  final ChatMessageType type;
  final String? text;
  final bool isMine;
  final DateTime sentAt;

  final String? fileName;
  final int? fileSize;
  final List<int>? fileBytes;

  ChatMessage.text({
    required String this.text,
    required this.isMine,
    required this.sentAt,
  }) : type = ChatMessageType.text,
       fileName = null,
       fileSize = null,
       fileBytes = null;

  ChatMessage.file({
    required this.fileName,
    required this.fileSize,
    required this.fileBytes,
    required this.isMine,
    required this.sentAt,
  }) : type = ChatMessageType.file,
       text = null;
}
