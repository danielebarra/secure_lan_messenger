import 'dart:async';

import 'package:flutter/material.dart';
import 'package:secure_lan_messenger/app_services.dart';
import 'package:secure_lan_messenger/models/chat_message.dart';
import 'package:secure_lan_messenger/models/peer_device.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  PeerDevice? connectedPeer;
  StreamSubscription<PeerDevice?>? connectedPeerSub;

  @override
  void initState() {
    super.initState();

    connectedPeer = AppServices.networkService.connectedPeer;

    connectedPeerSub = AppServices.networkService.connectedPeerStream.listen((
      peer,
    ) {
      if (!mounted) return;

      setState(() {
        connectedPeer = peer;
      });
    });

    AppServices.chatService.addListener(_refresh);
  }

  void _refresh() {
    if (!mounted) return;

    final shouldScroll = _isChatNearBottom();

    setState(() {});

    if (shouldScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!scrollController.hasClients) return;

        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  bool _isChatNearBottom() {
    if (!scrollController.hasClients) return true;

    final position = scrollController.position;

    return position.maxScrollExtent - position.pixels < 80;
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

  Widget _buildHeader() {
    final peerName = connectedPeer?.name ?? 'Nessun dispositivo';

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9DEE8)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsGeometry.directional(start: 10),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Color.fromARGB(255, 219, 201, 173),
              child: CircleAvatar(
                radius: 23,
                backgroundColor: Color.fromARGB(255, 255, 234, 201),
                child: Text(
                  peerName.length >= 2
                      ? peerName.substring(0, 2).toUpperCase()
                      : peerName.toUpperCase(),
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                peerName,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              SizedBox(height: 4),
              Text(
                connectedPeer != null ? "Connesso" : "Non Connesso",
                style: TextStyle(
                  color: connectedPeer != null ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Spacer(),
          Padding(
            padding: const EdgeInsetsGeometry.directional(end: 20),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color.fromARGB(255, 177, 177, 177),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        connectedPeer != null
                            ? Icons.verified_user
                            : Icons.gpp_bad,
                        color: connectedPeer != null
                            ? Colors.green
                            : Colors.red,
                      ),
                      SizedBox(width: 2),
                      Text(
                        connectedPeer != null
                            ? "AES-GCM attivo"
                            : "AES-GCM non attivo",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 7),
                Container(
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color.fromARGB(255, 177, 177, 177),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        connectedPeer != null
                            ? Icons.verified_user
                            : Icons.gpp_bad,
                        color: connectedPeer != null
                            ? Colors.green
                            : Colors.red,
                      ),
                      SizedBox(width: 6),
                      Text(
                        connectedPeer != null
                            ? "RSA verificato  "
                            : "RSA non verificato  ",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(List<ChatMessage> messages) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9DEE8)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: messages.isEmpty
          ? const Center(
              child: Text(
                'Nessun messaggio.\nQuando ti connetterai con un dispositivo potrai iniziare la chat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
              ),
            )
          : ListView.builder(
              controller: scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _MessageBubble(message: messages[index]);
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = AppServices.chatService.messages;

    return Container(
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9DEE8)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white),
              child: _buildMessagesArea(messages),
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
      ),
    );
  }

  @override
  void dispose() {
    AppServices.chatService.removeListener(_refresh);
    messageController.dispose();
    scrollController.dispose();
    connectedPeerSub?.cancel();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isMine = message.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF0B63CE) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMine ? Colors.white : const Color(0xFF111827),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _formatTime(message.sentAt),
              style: TextStyle(
                color: isMine ? Colors.white70 : const Color(0xFF6B7280),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, "0");
    final minute = time.minute.toString().padLeft(2, "0");

    return '$hour:$minute';
  }
}
