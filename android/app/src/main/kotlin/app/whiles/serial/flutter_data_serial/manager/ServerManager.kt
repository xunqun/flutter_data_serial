package app.whiles.serial.flutter_data_serial.manager

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.util.Log
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import app.whiles.serial.flutter_data_serial.constant.Constants
import app.whiles.serial.flutter_data_serial.constant.ServerConnectState
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.UUID
import kotlin.getValue

class ServerManager {

    // singleton instance
    companion object {


        @JvmStatic
        var instance: ServerManager? = null

        @JvmStatic
        fun get(): ServerManager {
            if(instance == null) {
                instance = ServerManager()
            }
            return instance!!
        }

    }

    // Bluetooth 相關屬性
    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var serverSocket: BluetoothServerSocket? = null
    private var serverThread: Thread? = null
    private var clientSocket: BluetoothSocket? = null

    // UUID 與服務名稱
    private val SERVICE_NAME = "FlutterDataSerialService"
    private val SERVICE_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // SPP UUID

    // LiveData to observe the received data
    private val _receivedDataLive: MutableLiveData<ByteArray> = MutableLiveData()
    val receivedDataLive: LiveData<ByteArray>
        get() = _receivedDataLive


    private val _serverConnectStateLive: MutableLiveData<ServerConnectState> = MutableLiveData(ServerConnectState.STOPPED)
    val serverConnectStateLive: MutableLiveData<ServerConnectState>
        get() = _serverConnectStateLive

    // Add methods and properties for managing server connections here
    // For example, you might have methods to start a server, stop it, or handle incoming connections.
    fun startServer() {
        if (serverThread != null && serverThread!!.isAlive) return // 已啟動
        serverThread = Thread {
            try {
                _serverConnectStateLive.postValue(ServerConnectState.STARTING)
                serverSocket = bluetoothAdapter?.listenUsingRfcommWithServiceRecord(SERVICE_NAME, SERVICE_UUID)
                clientSocket = serverSocket?.accept() // 阻塞等待 client 連線
                _serverConnectStateLive.postValue(ServerConnectState.CONNECTED)
                // 連線成功後監聽資料
                clientSocket?.let { socket ->
                    val inputStream = socket.inputStream
                    val buffer = ByteArray(2048)
                    val outputStream = ByteArrayOutputStream()
                    var bytes: Int
                    while (socket.isConnected) {
                        try {
                            val bytes = inputStream.read(buffer)
                            if (bytes > 0) {

                                handleIncomingBytes(buffer)
                                outputStream.reset() // 若已全部處理完
                            }
                        } catch (e: IOException) {
                            e.printStackTrace()
                            break
                        }
                    }
                }
            } catch (e: IOException) {
                e.printStackTrace()
            } finally {
                _serverConnectStateLive.postValue(ServerConnectState.STOPPED)
                serverSocket?.close()
            }
        }
        serverThread?.start()
    }


    private fun handleIncomingBytes(bytes: ByteArray) {
        _receivedDataLive.postValue(bytes)
    }

    fun stopServer() {
//         Logic to stop the server
        _serverConnectStateLive.postValue(ServerConnectState.STOPPED)
        try {
            serverSocket?.close()
            clientSocket?.close()
            serverThread?.interrupt()
        } catch (e: IOException) {
            e.printStackTrace()
        } finally {
            serverSocket = null
            clientSocket = null
            serverThread = null
        }
    }

    fun sendData(data: ByteArray) {
        // Logic to send data to connected clients
        clientSocket?.let { socket ->
            try {
                val outputStream = socket.outputStream
                outputStream.write(data)
                outputStream.flush()
            } catch (e: IOException) {
                e.printStackTrace()
            }
        }
    }
}

