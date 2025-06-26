import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_data_serial/platform/spp_helper.dart';
import 'package:flutter_data_serial/protocol/factory_client_packet.dart';

import '../model/connect_state.dart';
import 'BaseClient.dart';

class PacketClient with BaseClient{

  /// Singleton instance of PacketServer
  static PacketClient? _instance;

  /// Packets queue to hold the packets to be sent
  Queue<List<int>> packets = Queue<List<int>>();

  /// Timer to control the sending of packets
  Timer? packetTimer;

  /// Keep the file ID to file name mapping, this can be used to resend packets
  Map<int, String> fileIdMap = HashMap<int, String>();

  // Data streams
  Stream<ClientConnectState> connectStateStream = SppHelper.get().clientConnectStateStream;
  Stream<Uint8List> dataStream = SppHelper.get().clientReceivedDataStream;
  Stream<bool> scanStateStream = SppHelper.get().scanStateStream;
  Stream<List<Map<String, String?>>> scanResultSteam = SppHelper.get().scanResultsStream;

  PacketClient._internal(){
    // Initialize the timer for sending packets
    packetTimer = Timer.periodic(Duration(milliseconds: packetInterval), (timer) {
      if (packets.isNotEmpty) {
        final packet = packets.removeFirst();
        // Here you would send the packet to the client
        // For example, using a method like sendPacket(packet);
        SppHelper.get().sendData(packet);
        print('Sending packet: ${packet.length} bytes');
      }
    });
  }

  // Get the singleton instance
  static PacketClient get() {
    _instance ??= PacketClient._internal();
    return _instance!;
  }

  // Send internal asset file
  @override
  Future<void> sendAsset(String assetPath) async{
    var id = genId();
    var factory = await ClientPacketFactory.fromAsset(id, assetPath);
    packets.addAll(factory.getPackets());
  }

  // Send file in the storage
  @override
  Future<void> sendFile(File file) async{
    var id = genId();
    var factory = await ClientPacketFactory.fromFile(id, file);
    packets.addAll(factory.getPackets());
  }

  @override
  void connect(String address){
    SppHelper.get().connectAsClient(address);
  }

  @override
  void disconnect(){
    SppHelper.get().clientDisconnect();
  }

  @override
  void stopScan(){
    SppHelper.get().stopScan();
  }

  @override
  void scan(){
    SppHelper.get().scan();
  }

  @override
  Future<void> sendData(List<int> data) async{
    SppHelper.get().sendData(data);
  }
}