package app.whiles.serial.flutter_data_serial.manager

import android.bluetooth.BluetoothManager

class ClientManager {
    // singleton instance
    companion object {
        @JvmStatic
        val instance: ClientManager by lazy { ClientManager() }
    }

    var bluetoothManager: BluetoothManager? = null
    var bluetoothAdapter: android.bluetooth.BluetoothAdapter? = null

    fun init(bluetoothManager: BluetoothManager) {
        this.bluetoothManager = bluetoothManager
        this.bluetoothAdapter = bluetoothManager.adapter
        if (this.bluetoothAdapter == null) {
            throw IllegalStateException("Bluetooth is not supported on this device")
        }


    }

    // Add methods and properties for managing client connections here
    fun connectToServer(serverAddress: String) {
        // Logic to connect to a server
    }

    fun disconnectFromServer() {
        // Logic to disconnect from the server
    }

    fun sendDataToServer(data: String) {
        // Logic to send data to the connected server
    }

    fun receiveDataFromServer(): String {
        // Logic to receive data from the server
        return "Received data"
    }
}