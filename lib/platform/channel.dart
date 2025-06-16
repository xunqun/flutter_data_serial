import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_data_serial/model/connect_state.dart';

class Channel {
  // Singleton pattern to ensure only one instance of Channel exists
  static Channel? _instance;
  static Channel get() {
    if (_instance == null) {
      _instance = Channel();
      _instance!._internal();
    }
    return _instance!;
  }

  static const platform = MethodChannel('channel.whiles.app/bluetooth');
  StreamController<List<Map<String, String?>>> _scanResultsController = StreamController<List<Map<String, String?>>>.broadcast();
  Stream<List<Map<String, String?>>> get scanResultsStream => _scanResultsController.stream;

  StreamController<bool> _scanStateController = StreamController<bool>.broadcast();
  Stream<bool> get scanStateStream => _scanStateController.stream;

  StreamController<ClientConnectState> _clientConnectStateController = StreamController<ClientConnectState>.broadcast();
  Stream<ClientConnectState> get clientConnectStateStream => _clientConnectStateController.stream;

  StreamController<ServerConnectState> _serverConnectStateController = StreamController<ServerConnectState>.broadcast();
  Stream<ServerConnectState> get serverConnectStateStream => _serverConnectStateController.stream;

  StreamController<Uint8List> _serverReceivedDataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get serverReceivedDataStream => _serverReceivedDataController.stream;

  StreamController<Uint8List> _clientReceivedDataController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get clientReceivedDataStream => _clientReceivedDataController.stream;


  _internal(){
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'scanResults':
          // Handle scan results
          final List<Object?> results = call.arguments;
          final List<Map<String, String?>> list = results
              .whereType<Map>() // 过滤出 Map 类型
              .map((e) => Map<String, String?>.from(e as Map)) // 转换为 Map<String, String>
              .toList();
          _scanResultsController.add(list);
          break;
        case 'clientScanState':
          // Handle scan state changes
          final bool isScanning = call.arguments;
          _scanStateController.add(isScanning);
          break;
        case 'clientConnectState':
          // Handle connection state changes
          final String connectState = call.arguments;
          _clientConnectStateController.add(ClientConnectState.findByName(connectState));
          break;
        case 'serverConnectState':
          // Handle server connection state changes
          final String serverConnectState = call.arguments;
          _serverConnectStateController.add(ServerConnectState.findByName(serverConnectState));
          break;
        case 'serverReceivedData':
          // Handle received data from server
          final Uint8List data = call.arguments;
          // print("Server received data: $data");
          _serverReceivedDataController.add(data);
          break;
        case 'clientReceivedData':
          // Handle received data from client
          final Uint8List data = call.arguments;
          // print("Client received data: $data");
          _clientReceivedDataController.add(data);
          break;
      }
    });
  }

  Future<void> scan() async {
    try {
      await platform.invokeMethod('scan');
    } on PlatformException catch (e) {
      print("Failed to scan: '${e.message}'.");
    }
  }

  Future<void> stopScan() async {
    try {
      await platform.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      print("Failed to stop scan: '${e.message}'.");
    }
  }

  Future<void> connectAsClient(String deviceId) async {
    try {
      await platform.invokeMethod('connectAsClient', {'deviceId': deviceId});
    } on PlatformException catch (e) {
      print("Failed to connect: '${e.message}'.");
    }
  }

  Future<void> connectAsServer() async {
    try {
      await platform.invokeMethod('connectAsServer');
    } on PlatformException catch (e) {
      print("Failed to connect as server: '${e.message}'.");
    }
  }

  Future<void> serverStop() async {
    try {
      await platform.invokeMethod('serverStop');
    } on PlatformException catch (e) {
      print("Failed to disconnect server: '${e.message}'.");
    }
  }

  Future<void> clientDisconnect() async {
    try {
      await platform.invokeMethod('disconnect', null);
    } on PlatformException catch (e) {
      print("Failed to disconnect: '${e.message}'.");
    }
  }

  Future<void> sendData(List<int> data) async {
    try {
      Uint8List uint8list = Uint8List.fromList(data);
      await platform.invokeMethod('sendData', {'data': uint8list});
    } on PlatformException catch (e) {
      print("Failed to send data: '${e.message}'.");
    }
  }

  Future<void> serverSendResendPacket(int index) async{

  }

  // Future<void> sendData(String data) async {
  //   try {
  //     await platform.invokeMethod('sendData', {'data': data});
  //   } on PlatformException catch (e) {
  //     print("Failed to send data: '${e.message}'.");
  //   }
  // }
}