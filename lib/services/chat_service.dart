import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:secure_lan_messenger/models/chat_message.dart';
import 'package:secure_lan_messenger/models/peer_device.dart';
import 'package:secure_lan_messenger/services/network_service.dart';

class ChatService extends ChangeNotifier {
  final NetworkService networkService;

  final List<ChatMessage> _messages = [];
  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<PeerDevice?>? _connectedPeerSubscription;

  ChatService({required this.networkService});

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void startListening() {
    _messageSubscription = networkService.incomingMessages.listen((message) {
      _messages.add(
        ChatMessage(text: message, isMine: false, sentAt: DateTime.now()),
      );

      notifyListeners();
    });

    _connectedPeerSubscription = networkService.connectedPeerStream.listen((
      peer,
    ) {
      if (peer == null) {
        clearMessages();
      }
    });
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    await networkService.sendTextMessage(text);

    _messages.add(
      ChatMessage(text: text, isMine: true, sentAt: DateTime.now()),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectedPeerSubscription?.cancel();
    super.dispose();
  }
}
