import 'dart:async';

import 'package:flutter/services.dart';

class Channel {
  // Singleton pattern to ensure only one instance of Channel exists
  static Channel? _instance;
  static get() {
    if (_instance == null) {
      _instance = Channel();
      _instance!._internal();
    }
    return _instance;
  }

  static const platform = MethodChannel('channel.whiles.app/bluetooth');
  StreamController<List<Map<String, String>>> _scanResultsController = StreamController<List<Map<String, String>>>.broadcast();
  Stream<List<Map<String, String>>> get scanResultsStream => _scanResultsController.stream;


  _internal(){
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'scanResults':
          // Handle scan results
          final List<Object?> results = call.arguments;
          final List<Map<String, String>> list = results
              .whereType<Map>() // 过滤出 Map 类型
              .map((e) => Map<String, String>.from(e as Map)) // 转换为 Map<String, String>
              .toList();
          _scanResultsController.add(list);
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

  Future<void> disconnect(String deviceId) async {
    try {
      await platform.invokeMethod('disconnect', {'deviceId': deviceId});
    } on PlatformException catch (e) {
      print("Failed to disconnect: '${e.message}'.");
    }
  }

  Future<void> sendData(String deviceId, String data) async {
    try {
      await platform.invokeMethod('sendData', {'deviceId': deviceId, 'data': data});
    } on PlatformException catch (e) {
      print("Failed to send data: '${e.message}'.");
    }
  }
}