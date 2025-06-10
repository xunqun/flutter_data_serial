enum ClientConnectState {
  IDLE, // The client is in the process of connecting
  CONNECTING,
  CONNECTED;

  static findByName(String name) {
    return ClientConnectState.values.firstWhere(
      (state) => state.toString().split('.').last == name,
      orElse: () => ClientConnectState.IDLE,
    );
  }
}

enum ServerConnectState {
  STARTING, CONNECTED, STOP;

  static findByName(String name) {
    return ServerConnectState.values.firstWhere(
      (state) => state.toString().split('.').last == name,
      orElse: () => ServerConnectState.STOP,
    );
  }
}