import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_data_serial/model/connect_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../platform/channel.dart';
import '../util/packet_receiver.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {

  PacketReceiver dataReceiver = PacketReceiver();
  Image? image;

  @override
  void initState() {
    WakelockPlus.enable();
    super.initState();
    dataReceiver.onComplete = (data) {
      setState(() {
        image = null; // Reset image before loading new one
        image = Image.memory(data);
      });

    };
    Channel.get().serverReceivedDataStream.listen((data){
      dataReceiver.handleIncomingPacket(data, (index){
        // Handle packet index if needed
      });
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    Channel.get().serverStop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Screen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              StreamBuilder(
                  stream: Channel.get().serverConnectStateStream,
                  initialData: ServerConnectState.STOPPED,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      ServerConnectState? state = snapshot.data;
                      return Text(
                        state?.name ?? 'Unknown state',
                        style: const TextStyle(fontSize: 20),
                      );
                    } else {
                      return const Text(
                        'Waiting for server connection state...',
                        style: TextStyle(fontSize: 20),
                      );
                    }
                  }),
              StreamBuilder(
                  stream: Channel.get().serverConnectStateStream,
                  initialData: ServerConnectState.STOPPED,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      ServerConnectState? state = snapshot.data;
                      if (state == ServerConnectState.STOPPED) {
                        return ElevatedButton(
                          onPressed: () {
                            // Add your server-specific functionality here
                            // For example, start listening for connections
                            Channel.get().connectAsServer();
                          },
                          child: const Text('Start Server'),
                        );
                      } else if (state == ServerConnectState.STARTING) {
                        return const Text(
                          'Server is waiting for client ...',
                          style: TextStyle(color: Colors.red, fontSize: 20),
                        );
                      } else {
                        return ElevatedButton(
                          onPressed: () {
                            // Add your server-specific functionality here
                            // For example, stop the server
                            Channel.get().serverStop();
                          },
                          child: const Text('Stop Server'),
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  }),
              StreamBuilder(
                  stream: Channel.get().serverReceivedDataStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      Uint8List? data = snapshot.data;
                      String dataString = String.fromCharCodes(data!).trim();
                      return SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: Text(
                          dataString,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    } else {
                      return SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: const Text(
                          'Waiting for data from client...',
                          style: TextStyle(fontSize: 20),
                        ),
                      );
                    }
                  }),
              if(image != null)
                SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: image!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
