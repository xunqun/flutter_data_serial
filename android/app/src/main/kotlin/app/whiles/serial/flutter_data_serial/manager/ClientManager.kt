package app.whiles.serial.flutter_data_serial.manager

import android.Manifest
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.util.Log
import androidx.annotation.RequiresPermission
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import app.whiles.serial.flutter_data_serial.constant.ClientConnectState
import app.whiles.serial.flutter_data_serial.constant.Constants
import java.io.IOException
import java.util.UUID

class ClientManager {
    // singleton instance
    companion object {
        @JvmStatic
        var instance: ClientManager? = null

        @JvmStatic
        fun get(): ClientManager {
            if(instance == null) {
                instance = ClientManager()
            }
            return instance!!
        }
    }

    private var connectedSocket: BluetoothSocket? = null

    var bluetoothManager: BluetoothManager? = null
    var bluetoothAdapter: android.bluetooth.BluetoothAdapter? = null

    // LiveData to observe the connection state
    var _connStateLive: MutableLiveData<ClientConnectState> = MutableLiveData()
    val connStateLive: LiveData<ClientConnectState>
        get() = _connStateLive

    var _scanStateLive: MutableLiveData<Boolean> = MutableLiveData(false)
    val scanStateLive: LiveData<Boolean>
        get() = _scanStateLive

    var _scanResultsLive: MutableLiveData<List<HashMap<String, String>>> = MutableLiveData()
    val scanResultsLive: LiveData<List<HashMap<String, String>>>
        get() = _scanResultsLive
    val  discoveredDevices : MutableList<HashMap<String, String>> = mutableListOf()

    var _receivedDataLive: MutableLiveData<ByteArray> = MutableLiveData()
    val receivedDataLive: LiveData<ByteArray>
        get() = _receivedDataLive

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
        _connStateLive.postValue(ClientConnectState.IDLE)
        // 關閉 socket 並清理資源
        try {
            connectedSocket?.close()
            connectedSocket = null
        } catch (e: IOException) {
            Log.e("ClientManager", "Error closing socket", e)
        }
        Log.d("ClientManager", "Disconnected from server")
    }

    fun sendDataToServer(data: ByteArray) {
        // Logic to send data to the connected server
        connectedSocket?.let { socket ->
            try {
                val outputStream = socket.outputStream
                outputStream.write(data)
                outputStream.flush()
                Log.d("ClientManager", "Data sent to server: ${data.joinToString(",")}")
            } catch (e: IOException) {
                Log.e("ClientManager", "Error sending data to server", e)
            }
        } ?: run {
            Log.e("ClientManager", "No connected socket to send data")
        }
    }

//    fun sendDataToServer(data: String) {
//        // Logic to send data to the connected server
//        connectedSocket?.let { socket ->
//            try {
//                val outputStream = socket.outputStream
//                outputStream.write(data.toByteArray())
//                outputStream.flush()
//                Log.d("ClientManager", "Data sent to server: $data")
//            } catch (e: IOException) {
//                Log.e("ClientManager", "Error sending data to server", e)
//            }
//        } ?: run {
//            Log.e("ClientManager", "No connected socket to send data")
//        }
//    }

    fun receiveDataFromServer(): String {
        // Logic to receive data from the server
        return "Received data"
    }

    fun manageMyConnectedSocket(socket: BluetoothSocket) {
        // This method should handle the connected socket, e.g., start a thread to manage communication
        Log.d("ClientManager", "Connected to socket: ${socket.remoteDevice.address}")
        _connStateLive.postValue(ClientConnectState.CONNECTED)
        connectedSocket = socket
        Thread {
            try {
                val inputStream = socket.inputStream
                val buffer = ByteArray(1024)
                var bytes: Int
                while (socket.isConnected) {
                    bytes = inputStream.read(buffer)
                    if (bytes > 0) {
                        handleReceivedBytes(buffer, bytes)
                    }
                }
            } catch (e: IOException) {
                Log.e("ClientManager", "Error reading from server", e)
            } finally {
                _connStateLive.postValue(ClientConnectState.IDLE)
            }
        }.start()
    }

    private fun handleReceivedBytes(data: ByteArray, length: Int) {
        // 處理收到的 ByteArray 資料
        Log.d("ClientManager", "Received bytes from server: ${data.copyOf(length).joinToString(",")}")
        // 你可以在這裡進行自訂的資料處理
        val receivedString = String(data, 0, length)
        _receivedDataLive.postValue(data)
    }

    inner class ConnectThread(val device: BluetoothDevice) : Thread() {
        private val MY_UUID: UUID = UUID.fromString(Constants.UUID)
        private var mmSocket: BluetoothSocket? = null


        public override fun run() {
            // Cancel discovery because it otherwise slows down the connection.
            bluetoothAdapter?.cancelDiscovery()
            _connStateLive.postValue(ClientConnectState.CONNECTING)

            try {
                mmSocket = device.createRfcommSocketToServiceRecord(MY_UUID)
                    // Connect to the remote device through the socket. This call blocks
                    // until it succeeds or throws an exception.
                mmSocket!!.connect()
                    // The connection attempt succeeded. Perform work associated with
                    // the connection in a separate thread.
                manageMyConnectedSocket(mmSocket!!)
            } catch (e: IOException) {
                Log.e("ClientManager", "Could not connect to device: "+device.address, e)
                _connStateLive.postValue(ClientConnectState.IDLE)
                try {
                    mmSocket?.close()
                } catch (closeException: IOException) {
                    Log.e("ClientManager", "Could not close the client socket", closeException)
                }
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

