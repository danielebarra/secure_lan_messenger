import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:secure_lan_messenger/models/chat_message.dart';
import 'package:secure_lan_messenger/models/peer_device.dart';
import 'package:secure_lan_messenger/models/received_file.dart';
import 'package:secure_lan_messenger/services/network_service.dart';

class ChatService extends ChangeNotifier {
  final NetworkService networkService;

  final List<ChatMessage> _messages = [];
  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<ReceivedFile>? _fileSubscription;
  StreamSubscription<PeerDevice?>? _connectedPeerSubscription;

  ChatService({required this.networkService});

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void startListening() {
    _messageSubscription = networkService.incomingMessages.listen((message) {
      _messages.add(
        ChatMessage.text(text: message, isMine: false, sentAt: DateTime.now()),
      );

      notifyListeners();
    });

    _fileSubscription = networkService.incomingFiles.listen((file) {
      _messages.add(
        ChatMessage.file(
          fileName: file.fileName,
          fileSize: file.size,
          fileBytes: file.bytes,
          isMine: false,
          sentAt: file.receivedAt,
        ),
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
      ChatMessage.text(text: text, isMine: true, sentAt: DateTime.now()),
    );

    notifyListeners();
  }

  Future<void> sendFile({
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    await networkService.sendFile(filePath: filePath, fileName: fileName);

    _messages.add(
      ChatMessage.file(
        fileName: fileName,
        fileSize: bytes.length,
        fileBytes: bytes,
        isMine: true,
        sentAt: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectedPeerSubscription?.cancel();
    _fileSubscription?.cancel();
    super.dispose();
  }
}
