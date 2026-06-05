import 'dart:async';

import 'package:flutter/material.dart';
import 'package:secure_lan_messenger/app_services.dart';
import 'package:secure_lan_messenger/models/connection_request.dart';
import 'package:secure_lan_messenger/screens/chat_screen.dart';
import 'package:secure_lan_messenger/screens/discovery_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool isOnline = false;

  @override
  void initState() {
    super.initState();

    isOnline = AppServices.discoveryService.responderOnline;

    AppServices.discoveryService.incomingRequests.listen((request) {
      _showConnectionRequestDialog(request);
    });

    AppServices.discoveryService.isResponderOnline.listen((value) {
      _setOnlineStatus(value);
    });
  }

  int selectedIndex = 0;

  final List<String> pages = [
    "Cerca Dispositivi",
    "Chat",
    "Invio file",
    "Firma documento",
    "Verifica firma",
    "Impostazioni",
  ];

  Widget getCurrentScreen() {
    switch (selectedIndex) {
      case 0:
        return const DiscoveryScreen();
      case 1:
        return const ChatScreen();
      default:
        return Center(
          child: Text(
            pages[selectedIndex],
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                Expanded(child: getCurrentScreen()),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Versione 1.0", style: TextStyle(fontWeight: FontWeight.w600)),
          Text(
            "Porta in ascolto: 5000",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 15,
                color: isOnline ? Colors.green : Colors.red,
              ),
              SizedBox(width: 10),
              Text(
                isOnline ? "Online" : "Offline",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final items = [
      _SidebarItem(Icons.search, 'Cerca dispositivi'),
      _SidebarItem(Icons.chat_bubble_outline, 'Chat'),
      _SidebarItem(Icons.folder_outlined, 'Invio file'),
      _SidebarItem(Icons.edit_document, 'Firma documento'),
      _SidebarItem(Icons.verified_user_outlined, 'Verifica firma'),
      _SidebarItem(Icons.settings_outlined, 'Impostazioni'),
    ];

    return Container(
      width: 240,
      color: const Color(0xFF111827),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Secure LAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          for (int i = 0; i < items.length; i++)
            _buildSidebarButton(i, items[i]),

          const Spacer(),

          const Text(
            'Versione 1.0',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarButton(int index, _SidebarItem item) {
    final bool selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0B63CE) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: selected ? Colors.white : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConnectionRequestDialog(ConnectionRequest request) {
    StreamSubscription? cancelSub;

    cancelSub = AppServices.discoveryService.connectionCancelled.listen((id) {
      if (id != request.sessionId) return;

      cancelSub?.cancel();

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${request.fromDeviceName} ha annullato la connessione',
          ),
        ),
      );
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Richiesta di connessione'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${request.fromDeviceName} vuole connettersi.'),
              const SizedBox(height: 16),
              const Text('Codice di sicurezza'),
              Text(
                request.securityCode,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verifica che il codice sia identico su entrambi i dispositivi.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppServices.discoveryService.rejectConnection(request);
                Navigator.pop(context);
              },
              child: const Text('Rifiuta'),
            ),
            ElevatedButton(
              onPressed: () {
                AppServices.networkService.allowSession(
                  sessionId: request.sessionId,
                  remoteDeviceId: request.fromDeviceId,
                );
                AppServices.discoveryService.acceptConnection(request);
                Navigator.pop(context);
              },
              child: const Text('Accetta'),
            ),
          ],
        );
      },
    );
  }

  void _setOnlineStatus(bool value) {
    setState(() {
      if (isOnline == value) return;
      isOnline = value;
    });
  }

  @override
  void dispose() {
    AppServices.discoveryService.closeResponder();
    AppServices.chatService.dispose();
    AppServices.cryptoService.clearSessionKey();
    super.dispose();
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;

  _SidebarItem(this.icon, this.label);
}
