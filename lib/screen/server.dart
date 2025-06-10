import 'package:flutter/material.dart';

import '../platform/channel.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const Text(
              'This is the server screen.',
            ),
            ElevatedButton(
              onPressed: () {
                // Add your server-specific functionality here
                // For example, start listening for connections
                Channel.get().connectAsServer();
              },
              child: const Text('Start Server'),
            ),
          ],
        ),
      ),
    );
  }
}
