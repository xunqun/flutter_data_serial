package app.whiles.serial.flutter_data_serial.manager

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.util.Log
import androidx.annotation.RequiresPermission
import app.whiles.serial.flutter_data_serial.constant.Constants
import java.io.IOException
import java.util.UUID

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
    fun connectAsClient(address: String) {
        // Logic to connect to a server
        val device: BluetoothDevice? = bluetoothAdapter?.getRemoteDevice(address)
        if (device != null) {
            val connectThread = ConnectThread(device)
            connectThread.start()
        } else {
            Log.e("ClientManager", "Device not found with address: $address")
        }
    }

    fun disconnect() {
        // Logic to disconnect from the server
        Log.d("ClientManager", "Disconnected from server")
    }

    fun sendDataToServer(data: String) {
        // Logic to send data to the connected server
    }

    fun receiveDataFromServer(): String {
        // Logic to receive data from the server
        return "Received data"
    }

    fun manageMyConnectedSocket(socket: BluetoothSocket) {
        // This method should handle the connected socket, e.g., start a thread to manage communication
        Log.d("ClientManager", "Connected to socket: ${socket.remoteDevice.address}")
        // You can implement your communication logic here
    }

    inner class ConnectThread(val device: BluetoothDevice) : Thread() {
        private val MY_UUID: UUID = UUID.fromString(Constants.UUID)
        private var mmSocket: BluetoothSocket? = null

        public override fun run() {
            // Cancel discovery because it otherwise slows down the connection.
            bluetoothAdapter?.cancelDiscovery()
            var mmSocket: BluetoothSocket = device.createRfcommSocketToServiceRecord(MY_UUID)
            mmSocket.let { socket: BluetoothSocket ->
                // Connect to the remote device through the socket. This call blocks
                // until it succeeds or throws an exception.
                socket.connect()

                // The connection attempt succeeded. Perform work associated with
                // the connection in a separate thread.
                manageMyConnectedSocket(socket)
            }
        }

        // Closes the client socket and causes the thread to finish.
        fun cancel() {
            try {
                mmSocket?.close()
            } catch (e: IOException) {
                e.printStackTrace()
            }
        }
    }
}

