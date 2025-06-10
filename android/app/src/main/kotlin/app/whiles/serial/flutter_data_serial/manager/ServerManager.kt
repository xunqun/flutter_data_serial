package app.whiles.serial.flutter_data_serial.manager

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import java.io.IOException
import java.util.UUID
import kotlin.getValue

class ServerManager {

    // singleton instance
    companion object {
        @JvmStatic
        val instance: ServerManager by lazy { ServerManager() }
    }

    // Bluetooth 相關屬性
    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var serverSocket: BluetoothServerSocket? = null
    private var serverThread: Thread? = null
    private var clientSocket: BluetoothSocket? = null

    // UUID 與服務名稱
    private val SERVICE_NAME = "FlutterDataSerialService"
    private val SERVICE_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // SPP UUID

    // Add methods and properties for managing server connections here
    // For example, you might have methods to start a server, stop it, or handle incoming connections.
    fun startServer() {
        if (serverThread != null && serverThread!!.isAlive) return // 已啟動
        serverThread = Thread {
            try {
                serverSocket = bluetoothAdapter?.listenUsingRfcommWithServiceRecord(SERVICE_NAME, SERVICE_UUID)
                clientSocket = serverSocket?.accept() // 阻塞等待 client 連線
                // 連線成功後監聽資料
                clientSocket?.let { socket ->
                    val inputStream = socket.inputStream
                    val buffer = ByteArray(1024)
                    var bytes: Int
                    while (socket.isConnected) {
                        try {
                            bytes = inputStream.read(buffer)
                            if (bytes > 0) {
                                val received = String(buffer, 0, bytes)
                                // 這裡可以呼叫 handleIncomingConnection(received)
                                println("Received: $received")
                            }
                            handleIncomingBytes(bytes)
                        } catch (e: IOException) {
                            e.printStackTrace()
                            break
                        }
                    }
                }
            } catch (e: IOException) {
                e.printStackTrace()
            } finally {
                serverSocket?.close()
            }
        }
        serverThread?.start()
    }

    private fun handleIncomingBytes(bytes: kotlin.Int) {

    }

    fun stopServer() {
        // Logic to stop the server
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
        } ?: run {
            println("No client connected to send data.")
        }
    }
}

