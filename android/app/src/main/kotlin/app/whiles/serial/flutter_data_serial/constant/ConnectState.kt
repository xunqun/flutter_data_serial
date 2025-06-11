package app.whiles.serial.flutter_data_serial.constant

enum class ServerConnectState {
    STARTING, CONNECTED, STOPPED
}

enum class ClientConnectState {
    IDLE,
    CONNECTING,
    CONNECTED
}