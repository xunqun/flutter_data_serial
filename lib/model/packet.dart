import 'dart:typed_data';

const int maxPacketSize = 512;
const int headerSize = 2 + 1 + 2 + 2 + 2; // AA55 + TYPE + INDEX + LENGTH + CRC16
const List<int> headerBytes = [0xAA, 0x55];

enum PacketType {
  start,
  data,
  end,
  ack,
  resendReq,
}

int packetTypeToByte(PacketType type) {
  switch (type) {
    case PacketType.start: return 0x01;
    case PacketType.data: return 0x02;
    case PacketType.end: return 0x03;
    case PacketType.ack: return 0x04;
    case PacketType.resendReq: return 0x05;
  }
}

List<int> buildPacket({
  required PacketType type,
  required int index,
  required List<int> data,
}) {
  final typeByte = packetTypeToByte(type);
  final indexBytes = ByteData(2)..setUint16(0, index, Endian.big);
  final lengthBytes = ByteData(2)..setUint16(0, data.length, Endian.big);

  final payload = <int>[
    typeByte,
    ...indexBytes.buffer.asUint8List(),
    ...lengthBytes.buffer.asUint8List(),
    ...data,
  ];

  final checksum = calculateChecksum16(data);

  return [
    ...headerBytes,
    ...payload,
    checksum,
  ];
}

int calculateChecksum16(List<int> data) {
  int sum = 0;
  for (final byte in data) {
    sum += byte;
  }
  return sum & 0xFFFF; // 保持 16-bit
}