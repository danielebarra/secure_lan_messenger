class ChatMessage {
  final String text;
  final bool isMine;
  final DateTime sentAt;

  ChatMessage({required this.text, required this.isMine, required this.sentAt});
}
