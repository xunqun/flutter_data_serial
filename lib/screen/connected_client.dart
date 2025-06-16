import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_data_serial/util/packet_sender.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/connect_state.dart';
import '../platform/channel.dart';

class ConnectedClientScreen extends StatefulWidget {
  const ConnectedClientScreen({super.key});

  @override
  State<ConnectedClientScreen> createState() => _ConnectedClientScreenState();
}

class _ConnectedClientScreenState extends State<ConnectedClientScreen> {
  TextEditingController controller = TextEditingController();
  StreamSubscription? connStateSub;
  int progress = 0;
  List<String> imageList = [
    'assets/image/1.jpg',
    'assets/image/2.jpg',
    'assets/image/3.jpg',
    'assets/image/4.jpg',
    'assets/image/5.jpg',
    'assets/image/6.jpg',
    'assets/image/7.jpg',
    'assets/image/8.jpg',
    'assets/image/9.jpg',
    'assets/image/10.jpg',
  ];

  @override
  void initState() {
    WakelockPlus.enable();
    // listen to connect state changes
    connStateSub = Channel.get().clientConnectStateStream.listen((connectState) {
      if (connectState == ClientConnectState.IDLE) {
        // Navigate back to the client screen when disconnected
        Navigator.pop(context);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    connStateSub?.cancel();
    Channel.get().clientDisconnect();
    WakelockPlus.disable();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Client'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context); // Close the connected client screen
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Enter data to send',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Handle sending data
                        String dataToSend = controller.text;
                        if (dataToSend.isNotEmpty) {
                          // Here you would typically send the data to the connected client
                          // For example, using a method from your Channel class
                          Channel.get().sendData(dataToSend.codeUnits);
                          print(
                              'Sending data: $dataToSend'); // Placeholder for actual send logic
                          controller
                              .clear(); // Clear the input field after sending
                        }
                      },
                      icon: Icon(Icons.send),
                    )
                  ],
                ),
                SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: StreamBuilder<Uint8List>(
                      stream: Channel.get().clientReceivedDataStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          Uint8List? data = snapshot.data;
                          String dataString = String.fromCharCodes(data!).trim();
                          return Text(dataString,
                              style: const TextStyle(fontSize: 20));
                        } else if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }
                        return Text('');
                      }),
                ),
                // image button with asset image
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var image in imageList)
                        IconButton(
                          onPressed: () {
                            // Handle sending image
                            var start = DateTime.now().millisecondsSinceEpoch;
                            PacketSender.fromAsset(image).then((filePacketHelper) async {
                              List<List<int>> packets = filePacketHelper.getPackets();
                              int count = 0;
                              for (var packet in packets) {
                                Channel.get().sendData(packet);
                                count++;
                                setState(() {
                                  progress = (count / packets.length * 100).toInt();
                                });
                                await Future.delayed(Duration(milliseconds: 20));
                              }
                              var delta = DateTime.now().millisecondsSinceEpoch - start;
                              debugPrint(
                                  '✅ Image sent: $image, total packets: ${packets.length}, time taken: ${delta}ms');
                            });
                          },
                          icon: Image.asset(
                            image,
                            width: 50,
                            height: 50,
                          ),
                        ),
                    ],
                  ),
                ),
                CircularProgressIndicator(value: progress / 100)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
