import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_data_serial/platform/spp_helper.dart';
import 'package:flutter_data_serial/protocol/factory_client_packet.dart';

import '../model/connect_state.dart';
import '../model/packet.dart';
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

    // Listen for incoming data
    SppHelper.get().clientReceivedDataStream.listen((data) {
      // Handle incoming data
      // You can process the data here or pass it to a handler
      print('Received data: ${data.length} bytes');
      handleReceivedData(data);
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
    fileIdMap[id] = assetPath;
  }

  // Send file in the storage
  @override
  Future<void> sendFile(File file) async{
    var id = genId();
    var factory = await ClientPacketFactory.fromFile(id, file);
    packets.addAll(factory.getPackets());
    fileIdMap[id] = file.path;
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

  void handleReceivedData(Uint8List data) async{
    // 處理重傳請求
    final type = data[2];
    final fileId = (data[3] << 8) | data[4];
    final index = (data[5] << 8) | data[6];

    if (type == packetTypeToByte(PacketType.resendReq)) {
      print('🔄 Resend request for index $index');
      var file = fileIdMap[fileId]; // 儲存檔案ID與名稱的對應關係
      if(file == null) return;
      var isAsset = file.startsWith('assets/');
      var factory = isAsset
          ? await ClientPacketFactory.fromAsset(fileId, file)
          : await ClientPacketFactory.fromFile(fileId, File(file));

      // 重新發送指定索引的封包
      var packets = factory.getPackets();
      if (index < packets.length) {
        final resendPacket = packets[index];
        // 這裡可以添加發送邏輯，例如通過通道發送
        SppHelper.get().sendData(resendPacket);
      } else {
        print('❌ Invalid resend request for index $index');
      }

    } else {
      print('⚠️ Unknown resend request type: $type');
    }
  }
}