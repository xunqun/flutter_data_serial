import 'dart:typed_data';

class PacketReceiver {
  static const List<int> header = [0xAA, 0x55];
  static const int headerLength = 2;
  static const int metaLength = 1 + 2 + 2; // type + index + length
  static const int checksumLength = 2;

  int? totalSize;
  int? totalChunks;
  String postfix = '';
  final Map<int, List<int>> receivedChunks = {};
  final List<List<int>> resentPackets = [];
  bool isEndReceived = false;
  void Function(Uint8List imageData)? onComplete;
  Uint8List incompleteBuffer = Uint8List(0);

  void handleIncomingPacket(
      Uint8List buffer, void Function(List<List<int>>) sendResendRequest) {

    incompleteBuffer = Uint8List.fromList(
        incompleteBuffer.toList() + buffer.toList()); // 累積接收的資料
    final headerIndex = _findHeaderIndex(incompleteBuffer);
    if (headerIndex == -1) {
      print('⚠️ No valid header found in the buffer');
      return; // 沒有找到有效的 header
    }

    // 從找到的 header 開始處理
    buffer = incompleteBuffer.sublist(headerIndex);



    // if (buffer.length < headerLength + metaLength + checksumLength) return;

    // 驗證 header
    if (buffer[0] != header[0] || buffer[1] != header[1]) return;

    // 拆封
    final type = buffer[2];
    final index = (buffer[3] << 8) | buffer[4];
    final length = (buffer[5] << 8) | buffer[6];
    final dataStart = 7;
    final dataEnd = dataStart + length;
    final packetEnd = dataEnd + checksumLength;

    buffer = buffer.sublist(0, packetEnd); // 確保只處理完整的封包
    incompleteBuffer = Uint8List.fromList(
        buffer.sublist(packetEnd)); // 更新未完成的緩衝區

    if (buffer.length < dataEnd + 2) {
      print(
          '⚠️ Packet too short: expected at least ${dataEnd + 2} bytes, got ${buffer.length}');
      return; // 檢查長度完整
    }

    final data = buffer.sublist(dataStart, dataEnd);
    final receivedChecksum = (buffer[dataEnd] << 8) | buffer[dataEnd + 1];

    // 驗證 checksum
    final crcInput = buffer.sublist(2, dataEnd);
    if (_calculateChecksum16(Uint8List.fromList(crcInput)) !=
        receivedChecksum) {
      print('❌ checksum error at index $index');
      var resentPacket = buildResetPacket(index);
      resentPackets.add(resentPacket);

      sendResendRequest(resentPackets);
      return;
    }

    if (type == 0x01) {
      // START
      if (data.length >= 8) {
        totalSize = ByteData.sublistView(Uint8List.fromList(data), 0, 4)
            .getUint32(0, Endian.big);
        totalChunks = ByteData.sublistView(Uint8List.fromList(data), 4, 8)
            .getUint32(0, Endian.big);
        postfix = String.fromCharCodes(data.sublist(8, 12));
        receivedChunks.clear();
        print(
            '✅ START received: totalSize=$totalSize, chunks=$totalChunks, postfix="$postfix"');
      }
    } else if (type == 0x02) {
      // DATA
      if (!receivedChunks.containsKey(index)) {
        receivedChunks[index] = data;
        print('📦 DATA $index received (${data.length} bytes)');
      }
    } else if (type == 0x03) {
      // END
      isEndReceived = true;
      print('✅ END received');
      _checkCompletion(sendResendRequest);
    } else {
      print('⚠️ Unknown packet type: $type at index $index');
    }
  }

  int _findHeaderIndex(Uint8List buffer) {
    for (int i = 0; i < buffer.length - headerLength; i++) {
      if (buffer[i] == header[0] && buffer[i + 1] == header[1]) {
        return i;
      }
    }
    return -1;
  }

  void _checkCompletion(void Function(List<List<int>>) sendResendRequest) {
    if (totalChunks == null || !isEndReceived) return;

    final missing = <int>[];
    for (int i = 0; i < totalChunks!; i++) {
      if (!receivedChunks.containsKey(i)) {
        missing.add(i);
      }
    }

    if (missing.isEmpty) {
      print('🎉 檔案接收完成，總大小: ${_rebuildFile().length} bytes');
      final data = _rebuildFile();
      if (onComplete != null) {
        onComplete!(data);
      }
    } else {
      print('⚠️ 發現遺失封包: ${missing.length} 個 → $missing');
      for (final index in missing) {
        resentPackets.add(buildResetPacket(index));
      }
      sendResendRequest(resentPackets);
    }
  }

  /// 重組整個檔案內容
  Uint8List _rebuildFile() {
    final sorted =
        List.generate(receivedChunks.length, (i) => receivedChunks[i] ?? [])
            .expand((e) => e)
            .toList();
    return Uint8List.fromList(sorted);
  }

  int _calculateChecksum16(Uint8List data) {
    int sum = 0;
    for (final b in data) {
      sum += b;
    }
    return sum & 0xFFFF;
  }

  List<int> buildResetPacket(int index) {
    var data = [(index >> 8) & 0xFF, index & 0xFF];
    final packet = <int>[
      header[0], header[1], // Header
      0x05, // Type: Resend Request
      0x00, 0x00, // Index
      0x00, 0x02, // Length: 2 bytes (for index)
    ];
    packet.addAll(data);
    // 計算 checksum

    final checksum =
        _calculateChecksum16(Uint8List.fromList(packet.sublist(2)));
    packet.add((checksum >> 8) & 0xFF);
    packet.add(checksum & 0xFF);

    return Uint8List.fromList(packet);
  }
}
