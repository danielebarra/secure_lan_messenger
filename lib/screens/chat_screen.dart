import 'package:flutter/material.dart';
import 'package:secure_lan_messenger/app_services.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();

    AppServices.chatService.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty) return;

    try {
      await AppServices.chatService.sendMessage(text);
      messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore invio messaggio: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = AppServices.chatService.messages;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: messages.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(messages[index].text),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Manda un messaggio",
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) => sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: sendMessage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    AppServices.chatService.removeListener(_refresh);
    messageController.dispose();
    super.dispose();
  }
}
