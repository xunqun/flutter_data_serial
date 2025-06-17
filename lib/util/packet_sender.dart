import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';

import '../model/packet.dart';
import '../platform/channel.dart';

class PacketSender {


  final Uint8List fileBytes;
  final String postfix;
  final List<List<int>> packets = [];

  PacketSender._(this.fileBytes, this.postfix);

  /// 建立實例並切分封包
  static Future<PacketSender> fromFile(File file) async {
    final bytes = await file.readAsBytes();
    final postfix = file.path.split('.').last.toLowerCase();
    final helper = PacketSender._(bytes, postfix);
    helper._buildPackets();
    return helper;
  }

  // final helper = await FilePacketHelper.fromAsset('assets/image/sample.jpg');
  // final packets = helper.getPackets();
  static Future<PacketSender> fromAsset(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final postfix = assetPath.split('.').last.toLowerCase();
    final data = bytes.buffer.asUint8List();
    final helper = PacketSender._(data, postfix);
    helper._buildPackets();
    return helper;
  }

  void _buildPackets() {
    int totalSize = fileBytes.length;
    int totalChunks = (totalSize / packetSize).ceil();
    Uint8List postfixBytes = Uint8List.fromList(postfix.codeUnits);
    // 1. START Packet
    final startPayload = ByteData(12)
      ..setUint32(0, totalSize, Endian.big)
      ..setUint32(4, totalChunks, Endian.big);

    // postfix bytes are added to byte 8 to 11
    for (int i = 0; i < postfixBytes.length; i++) {
      startPayload.setUint8(8 + i, postfixBytes[i]);
    }
    // Fill remaining bytes with 0 if postfix is less than 4 bytes
    for (int i = postfixBytes.length; i < 4; i++) {
      startPayload.setUint8(8 + i, 0);
    }

    packets.add(_buildPacket(PacketType.start, 0, startPayload.buffer.asUint8List()));

    // 2. DATA Packets
    for (int i = 0; i < totalChunks; i++) {
      final start = i * packetSize;
      final end = (start + packetSize).clamp(0, fileBytes.length);
      final chunk = fileBytes.sublist(start, end);
      packets.add(_buildPacket(PacketType.data, i, chunk));
    }

    // 3. END Packet
    packets.add(_buildPacket(PacketType.end, 0, []));
  }

  List<int> _buildPacket(PacketType type, int index, List<int> data) {
    final List<int> packetBody = [];

    // TYPE
    final typeByte = packetTypeToByte(type);
    packetBody.add(typeByte);

    // INDEX (2 bytes)
    final indexBytes = ByteData(2)..setUint16(0, index, Endian.big);
    packetBody.addAll(indexBytes.buffer.asUint8List());

    // LENGTH (2 bytes)
    final lenBytes = ByteData(2)..setUint16(0, data.length, Endian.big);
    packetBody.addAll(lenBytes.buffer.asUint8List());

    // DATA
    packetBody.addAll(data);

    // CHECKSUM (對上面部分加總)
    final checksum = _calculateChecksum16(Uint8List.fromList(packetBody));
    final checksumBytes = ByteData(2)..setUint16(0, checksum, Endian.big);

    return [
      ...headerBytes,
      ...packetBody,
      ...checksumBytes.buffer.asUint8List(),
    ];
  }

  handleResendRequest(List<int> packet) {
    // 處理重傳請求
    final type = packet[2];
    final index = (packet[3] << 8) | packet[4];

    if (type == packetTypeToByte(PacketType.resendReq)) {
      print('🔄 Resend request for index $index');
      // 重新發送指定索引的封包
      if (index < packets.length) {
        final resendPacket = packets[index];
        // 這裡可以添加發送邏輯，例如通過通道發送
        Channel.get().sendData(resendPacket);
      } else {
        print('❌ Invalid resend request for index $index');
      }
    } else {
      print('⚠️ Unknown resend request type: $type');
    }
  }


  int _calculateChecksum16(Uint8List data) {
    int sum = 0;
    for (final b in data) {
      sum += b;
    }
    return sum & 0xFFFF;
  }

  /// 對外提供封包清單
  List<List<int>> getPackets() => packets;
}