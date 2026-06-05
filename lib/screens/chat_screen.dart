import 'dart:async';

import 'package:flutter/material.dart';
import 'package:secure_lan_messenger/app_services.dart';
import 'package:secure_lan_messenger/models/peer_device.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();

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

  Widget _buildHeader() {
    final peerName = connectedPeer?.name ?? 'Nessun dispositivo';

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9DEE8)),
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

  @override
  Widget build(BuildContext context) {
    final messages = AppServices.chatService.messages;

    return Column(
      children: [
        _buildHeader(),
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
    connectedPeerSub?.cancel();
    super.dispose();
  }
}
