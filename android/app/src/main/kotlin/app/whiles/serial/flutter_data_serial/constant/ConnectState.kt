package app.whiles.serial.flutter_data_serial.constant

enum class ServerConnectState {
    STARTING, CONNECTED, STOP
}

enum class ClientConnectState {
    IDLE,
    CONNECTING,
    CONNECTED
}