import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';

import '../model/packet.dart';

class FilePacketHelper {


  final Uint8List fileBytes;
  final List<List<int>> packets = [];

  FilePacketHelper._(this.fileBytes);

  /// 建立實例並切分封包
  static Future<FilePacketHelper> fromFile(File file) async {
    final bytes = await file.readAsBytes();
    final helper = FilePacketHelper._(bytes);
    helper._buildPackets();
    return helper;
  }

  // final helper = await FilePacketHelper.fromAsset('assets/image/sample.jpg');
  // final packets = helper.getPackets();
  static Future<FilePacketHelper> fromAsset(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final data = bytes.buffer.asUint8List();
    final helper = FilePacketHelper._(data);
    helper._buildPackets();
    return helper;
  }

  void _buildPackets() {
    int totalSize = fileBytes.length;
    int totalChunks = (totalSize / maxPacketSize).ceil();

    // 1. START Packet
    final startPayload = ByteData(8)
      ..setUint32(0, totalSize, Endian.big)
      ..setUint32(4, totalChunks, Endian.big);
    packets.add(_buildPacket(PacketType.start, 0, startPayload.buffer.asUint8List()));

    // 2. DATA Packets
    for (int i = 0; i < totalChunks; i++) {
      final start = i * maxPacketSize;
      final end = (start + maxPacketSize).clamp(0, fileBytes.length);
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