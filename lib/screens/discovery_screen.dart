import 'dart:async';

import 'package:flutter/material.dart';
import 'package:secure_lan_messenger/app_services.dart';

import 'package:secure_lan_messenger/models/peer_device.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final discoveryService = AppServices.discoveryService;

  List<PeerDevice> devices = [];
  bool isScanning = false;
  PeerDevice? selectedDevice;
  String lastScan = '-';
  bool isOnline = false;

  StreamSubscription<PeerDevice?>? connectedPeerSub;
  PeerDevice? connectedPeer;

  StreamSubscription<bool>? onlineSub;

  @override
  void initState() {
    super.initState();

    isOnline = AppServices.discoveryService.responderOnline;

    onlineSub = AppServices.discoveryService.isResponderOnline.listen((value) {
      if (!mounted) return;
      _setOnlineStatus(value);
    });

    connectedPeer = AppServices.networkService.connectedPeer;

    connectedPeerSub = AppServices.networkService.connectedPeerStream.listen((
      peer,
    ) {
      if (!mounted) return;

      setState(() {
        connectedPeer = peer;

        if (peer != null &&
            !devices.any((device) => device.deviceId == peer.deviceId)) {
          devices.add(peer);
        }
      });
    });
  }

  Future<void> scanDevices() async {
    setState(() {
      isScanning = true;
      selectedDevice = null;
    });

    try {
      final result = await discoveryService.scanDevices();

      final connected = AppServices.networkService.connectedPeer;

      if (connected != null &&
          !result.any((device) => device.deviceId == connected.deviceId)) {
        result.add(connected);
      }

      if (!mounted) return;

      setState(() {
        devices = result;
        isScanning = false;
        lastScan = TimeOfDay.now().format(context);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isScanning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la scansione: $e')),
      );
    }
  }

  void selectDevice(PeerDevice device) {
    setState(() {
      selectedDevice = device;
    });
  }

  Future<void> startConnection() async {
    final device = selectedDevice;

    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seleziona prima un dispositivo")),
      );
      return;
    }

    final requestData = await discoveryService.sendConnectionRequest(device);

    if (!mounted) return;

    _showOutgoingConnectionModal(
      peer: device,
      sessionId: requestData['sessionId']!,
      securityCode: requestData['securityCode']!,
    );
  }

  void disconnect() {
    AppServices.networkService.disconnectPeer();

    if (!mounted) return;

    setState(() {
      connectedPeer = null;
    });
  }

  void _showOutgoingConnectionModal({
    required PeerDevice peer,
    required String sessionId,
    required String securityCode,
  }) {
    StreamSubscription? acceptedSub;
    StreamSubscription? rejectedSub;

    acceptedSub = AppServices.discoveryService.connectionAccepted.listen((
      id,
    ) async {
      if (id != sessionId) return;

      acceptedSub?.cancel();
      rejectedSub?.cancel();

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final connected = await AppServices.networkService.connectToPeer(
        peer: peer,
        sessionId: sessionId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'Connessione TCP stabilita con ${peer.name}'
                : 'Errore durante la connessione TCP con ${peer.name}',
          ),
        ),
      );
    });

    rejectedSub = AppServices.discoveryService.connectionRejected.listen((id) {
      if (id != sessionId) return;

      acceptedSub?.cancel();
      rejectedSub?.cancel();

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${peer.name} ha rifiutato la connessione')),
      );
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Richiesta inviata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Richiesta di connessione inviata a ${peer.name}.'),
              const SizedBox(height: 20),
              const Text('Codice di sicurezza'),
              Text(
                securityCode,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Verifica che il codice sia identico su entrambi i dispositivi.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text('In attesa di accettazione...'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppServices.discoveryService.cancelConnectionRequest(
                  sessionId: sessionId,
                  peer: peer,
                );

                acceptedSub?.cancel();
                rejectedSub?.cancel();

                Navigator.pop(context);
              },
              child: const Text('Annulla richiesta'),
            ),
          ],
        );
      },
    ).then((_) {
      acceptedSub?.cancel();
      rejectedSub?.cancel();
    });
  }

  void _setOnlineStatus(bool value) {
    if (!mounted) return;

    setState(() {
      if (isOnline == value) return;

      isOnline = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cerca dispositivi',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ricerca peer disponibili nella rete locale',
            style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              ElevatedButton.icon(
                onPressed: isOnline
                    ? isScanning
                          ? null
                          : scanDevices
                    : null,
                icon: isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  isScanning ? 'Scansione...' : 'Avvia scansione',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                ),
              ),

              const SizedBox(width: 12),

              OutlinedButton.icon(
                onPressed: isOnline
                    ? () {
                        discoveryService.stopResponder();
                        disconnect();
                      }
                    : discoveryService.startResponder,
                icon: Icon(
                  Icons.circle,
                  color: isOnline ? Colors.green : Colors.red,
                  size: 15,
                ),
                label: Text(isOnline ? 'Online' : "Offline"),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                ),
              ),

              const SizedBox(width: 20),

              const SizedBox(
                width: 340,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filtra per nome dispositivo o IP...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  title: isScanning
                      ? 'Scansione in corso'
                      : 'Ultima scansione completata',
                  subtitle: 'Subnet: 192.168.1.0/24',
                  icon: Icons.wifi_tethering,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InfoCard(
                  title: 'Dispositivi trovati: ${devices.length}',
                  subtitle: 'Ultimo aggiornamento: $lastScan',
                  icon: Icons.devices,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _DeviceList(
                    devices: devices,
                    selectedDevice: selectedDevice,
                    connectedPeer: connectedPeer,
                    onSelect: selectDevice,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _DeviceDetails(
                    device: selectedDevice,
                    connectedPeer: connectedPeer,
                    onConnect: startConnection,
                    onDisconnect: disconnect,
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
  void dispose() {
    onlineSub?.cancel();
    connectedPeerSub?.cancel();
    super.dispose();
  }
}

class _DeviceList extends StatelessWidget {
  final List<PeerDevice> devices;
  final PeerDevice? selectedDevice;
  final PeerDevice? connectedPeer;
  final ValueChanged<PeerDevice> onSelect;

  const _DeviceList({
    required this.devices,
    required this.selectedDevice,
    required this.connectedPeer,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Container(
        decoration: _cardDecoration(),
        child: const Center(
          child: Text(
            'Nessun dispositivo trovato.\nAvvia una scansione della rete locale.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD9DEE8)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: devices.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          final device = devices[index];
          final selected = selectedDevice == device;
          final isConnected = connectedPeer?.deviceId == device.deviceId;

          return ListTile(
            selected: selected,
            selectedTileColor: const Color(0xFFEAF2FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEAF2FF),
              child: Icon(Icons.computer, color: Color(0xFF0B63CE)),
            ),
            title: Text(
              device.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${device.ip}  •  Porta ${device.port}\nFingerprint: ${device.fingerprint}',
            ),
            trailing: Text(
              isConnected ? 'Connesso' : "Disponibile",
              style: const TextStyle(
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => onSelect(device),
          );
        },
      ),
    );
  }
}

class _DeviceDetails extends StatelessWidget {
  final PeerDevice? device;
  final PeerDevice? connectedPeer;
  final VoidCallback onDisconnect;
  final VoidCallback onConnect;

  const _DeviceDetails({
    required this.device,
    required this.onConnect,
    this.connectedPeer,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected =
        device != null && connectedPeer?.deviceId == device!.deviceId;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: device == null
          ? const Center(
              child: Text(
                'Seleziona un dispositivo',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dettaglio dispositivo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                Text(
                  device!.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                Text('IP: ${device!.ip}'),
                Text('Porta: ${device!.port}'),

                const SizedBox(height: 16),

                const Text(
                  'Fingerprint:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  device!.fingerprint,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    color: Color(0xFF374151),
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isConnected ? onDisconnect : onConnect,
                    icon: Icon(isConnected ? Icons.link_off : Icons.lock),
                    label: Text(
                      isConnected ? 'Disconnetti' : 'Avvia connessione',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9DEE8)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0B63CE), size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color(0xFFD9DEE8)),
    borderRadius: BorderRadius.circular(16),
  );
}
