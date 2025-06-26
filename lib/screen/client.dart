import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/connect_state.dart';
import '../platform/spp_helper.dart';
import 'connected_client.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  late SppHelper spp;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    spp = SppHelper.get();
    spp.scanStateStream.listen((scanning) {
      setState(() {
        isScanning = scanning;
      });
    });

    spp.clientConnectStateStream.listen((connectState) {
      if (connectState == ClientConnectState.CONNECTED) {
        // Navigate to the connected client screen
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ConnectedClientScreen()));

      } else {

      }
    });
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Screen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              const Text(
                'This is the client screen.',
              ),
              ElevatedButton(
                onPressed: () {
                  // Add your client-specific functionality here
                  if(isScanning) {
                    spp.stopScan();
                  } else {
                    spp.scan();
                  }
                },
                child: Text( isScanning ? 'stop' : 'Search for devices'),
              ),
              Expanded(child: StreamBuilder<List<Map<String, String?>>>(
                stream: spp.scanResultsStream,
                initialData: [],
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No devices found'));
                  }
                  final devices = snapshot.data!;
                  return ListView.builder(itemBuilder: (context, index) {
                    // Replace with your device list
                    return ListTile(
                      title: Text(devices[index]['name'] ?? 'Unknown Device'),
                      subtitle: Text(devices[index]['type'] ?? ''),
                      onTap: () {
                        // Handle device selection
                        spp.connectAsClient(devices[index]['address'] ?? '');
                      },
                    );
                  }, itemCount: devices.length,);
                }
              )),
            ],
          ),
        ),
      ),
    );
  }
}
