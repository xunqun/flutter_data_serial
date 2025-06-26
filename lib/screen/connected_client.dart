import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_data_serial/util/packet_sender.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/connect_state.dart';
import '../model/packet.dart';
import '../platform/spp_helper.dart';

class ConnectedClientScreen extends StatefulWidget {
  const ConnectedClientScreen({super.key});

  @override
  State<ConnectedClientScreen> createState() => _ConnectedClientScreenState();
}

class _ConnectedClientScreenState extends State<ConnectedClientScreen> {
  TextEditingController controller = TextEditingController();
  StreamSubscription? connStateSub;
  StreamSubscription? _dataSub;
  PacketSender? _sender;
  int progress = 0;
  int imageDeltaTime = 0;
  bool busy = false;
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
  List<String> naviList = [
    'assets/image/1_1.jpg',
    'assets/image/1_2.jpg',
    'assets/image/1_3.jpg',
    'assets/image/1_4.jpg',
    'assets/image/1_5.jpg',
    'assets/image/1_6.jpg',
    'assets/image/1_7.jpg',
    'assets/image/1_8.jpg',
    'assets/image/1_9.jpg',
    'assets/image/1_10.jpg',
  ];

  @override
  void initState() {
    WakelockPlus.enable();
    // listen to connect state changes
    connStateSub = SppHelper.get().clientConnectStateStream.listen((connectState) {
      if (connectState == ClientConnectState.IDLE) {
        // Navigate back to the client screen when disconnected
        Navigator.pop(context);
      }
    });
    _dataSub = SppHelper.get().clientReceivedDataStream.listen((data) {
      _sender?.handleResendRequest(data);
    });
    super.initState();
  }

  @override
  void dispose() {
    connStateSub?.cancel();
    _dataSub?.cancel();
    SppHelper.get().clientDisconnect();

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
                // Row(
                //   children: [
                //     SizedBox(
                //       width: 200,
                //       child: TextField(
                //         controller: controller,
                //         decoration: const InputDecoration(
                //           labelText: 'Enter data to send',
                //           border: OutlineInputBorder(),
                //         ),
                //       ),
                //     ),
                //     IconButton(
                //       onPressed: () {
                //         // Handle sending data
                //         String dataToSend = controller.text;
                //         if (dataToSend.isNotEmpty) {
                //           // Here you would typically send the data to the connected client
                //           // For example, using a method from your Channel class
                //           Channel.get().sendData(dataToSend.codeUnits);
                //           print(
                //               'Sending data: $dataToSend'); // Placeholder for actual send logic
                //           controller
                //               .clear(); // Clear the input field after sending
                //         }
                //       },
                //       icon: Icon(Icons.send),
                //     )
                //   ],
                // ),
                SizedBox(
                  height: 60,
                  width: double.infinity,
                  child: StreamBuilder<Uint8List>(
                      stream: SppHelper.get().clientReceivedDataStream,
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
                const SizedBox(height: 20),
                Text('Packet Size $packetSize bytes'),
                Slider(
                  value: packetSize.toDouble(),
                  min: 128,
                  max: 896,
                  divisions: 8,
                  label: 'Packet Size: $packetSize bytes',
                  onChanged: (value) {
                    setState(() {
                      packetSize = value.toInt();
                    });
                  },
                ),
                const SizedBox(height: 20),
                Text('Packet Interval $packetInterval ms'),
                Slider(
                  value: packetInterval.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 9,
                  label: 'Packet Interval: $packetInterval ms',
                  onChanged: (value) {
                    setState(() {
                      packetInterval = value.toInt();
                    });
                  },
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
                            setState(() {
                              busy = true;
                            });
                            sendImagePacket(image);
                            setState(() {
                              busy = false;
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
                ElevatedButton.icon( onPressed: busy ? null : () async {
                  // send all images
                  setState(() {
                    busy = true;
                  });
                  for (var image in imageList) {
                    await sendImagePacket(image);
                  }
                  setState(() {
                    busy = false;
                  });
                }, icon: Icon(Icons.numbers), label: Text('Send all images'),),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var image in naviList)
                        IconButton(
                          onPressed: () {
                            // Handle sending image
                            setState(() {
                              busy = true;
                            });
                            sendImagePacket(image);
                            setState(() {
                              busy = false;
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

                ElevatedButton.icon( onPressed: busy ? null : () async {
                  // send all images
                  setState(() {
                    busy = true;
                  });
                  for (var image in naviList) {
                    await sendImagePacket(image);
                  }
                  setState(() {
                    busy = false;
                  });
                }, icon: Icon(Icons.local_shipping_outlined), label: Text('Send all images'),),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(value: progress / 100),
                      const SizedBox(width: 16),
                      Text('$imageDeltaTime ms', style: const TextStyle(fontSize: 28, color: Colors.blue)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> sendImagePacket(String image) async{
    var start = DateTime.now().millisecondsSinceEpoch;
    var packetSender = await PacketSender.fromAsset(0, image);
    _sender = packetSender;
    List<List<int>> packets = packetSender.getPackets();
    int count = 0;
    for (var packet in packets) {
      await SppHelper.get().sendData(packet);
      count++;
      setState(() {
        progress = (count / packets.length * 100).toInt();
      });
      await Future.delayed(Duration(milliseconds: packetInterval));
    }
    setState(() {
      imageDeltaTime = DateTime.now().millisecondsSinceEpoch - start;
    });


  }
}
