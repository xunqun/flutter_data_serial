import 'package:flutter/material.dart';

import '../platform/channel.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  late Channel channel;

  @override
  void initState() {
    super.initState();
    channel = Channel.get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const Text(
              'This is the client screen.',
            ),
            ElevatedButton(
              onPressed: () {
                // Add your client-specific functionality here
                channel.scan();
              },
              child: const Text('Search for devices'),
            ),
            Expanded(child: StreamBuilder<List<Map<String, String>>>(
              stream: channel.scanResultsStream,
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
                      channel.connectAsClient(devices[index]['address'] ?? '');
                    },
                  );
                }, itemCount: devices.length,);
              }
            )),
          ],
        ),
      ),
    );
  }
}
