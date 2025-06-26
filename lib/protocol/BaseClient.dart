import 'dart:io';

mixin BaseClient {
  /// The accumulated file ID, used to ensure unique IDs for each file sent
  static int accumulatedFileId = 0;

  /// The size of each packet in bytes and the interval between packets in milliseconds
  final int packetSize = 896; // 每個封包的大小

  /// The interval between sending packets in milliseconds
  final int packetInterval = 50; // 封包發送間隔（毫秒）


  // Get a unique file ID
  int genId(){
    accumulatedFileId += 1;
    if(accumulatedFileId > 0xffff) accumulatedFileId = 1;
    return accumulatedFileId;
  }

  Future<void> sendAsset(String assetPath);

  Future<void> sendFile(File file);

  void scan();

  void stopScan();

  void connect(String address);

  void disconnect();

  Future<void> sendData(List<int> data);


}