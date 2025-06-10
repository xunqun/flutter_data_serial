package app.whiles.serial.flutter_data_serial

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.annotation.RequiresPermission
import androidx.core.app.ActivityCompat
import app.whiles.serial.flutter_data_serial.constant.ClientConnectState
import app.whiles.serial.flutter_data_serial.constant.ServerConnectState
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import app.whiles.serial.flutter_data_serial.manager.ClientManager
import app.whiles.serial.flutter_data_serial.manager.ServerManager

class MainActivity : FlutterActivity() {
    var imServer = false
    private var methodChannel: MethodChannel? = null
    lateinit var bluetoothManager: BluetoothManager
    lateinit var bluetoothAdapter: BluetoothAdapter
    val  discoveredDevices : MutableList<HashMap<String, String>> = mutableListOf()

    private val receiver = object : android.content.BroadcastReceiver() {
        @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            if (BluetoothDevice.ACTION_FOUND == action) {
                // Discovery has found a device
                val device: BluetoothDevice =
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)!!
                // Do something with the discovered device
                var map = hashMapOf<String, String>(
                    "name" to device.name,
                    "address" to device.address,
                    "type" to when (device.type) {
                        BluetoothDevice.DEVICE_TYPE_CLASSIC -> "Classic"
                        BluetoothDevice.DEVICE_TYPE_LE -> "LE"
                        BluetoothDevice.DEVICE_TYPE_DUAL -> "Dual"
                        else -> "Unknown"
                    }
                )
                discoveredDevices.add(map);
                sendScanResults(discoveredDevices)
            } else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED == action) {
                // Discovery has finished
                // You can notify the user or update the UI here
                sendScanResults(discoveredDevices)
                ClientManager.get()._scanStateLive.postValue(false)
                sendClientScanState(false)
            } else if (BluetoothAdapter.ACTION_DISCOVERY_STARTED == action) {
                // Discovery has started
                discoveredDevices.clear() // Clear previous scan results
                ClientManager.get()._scanStateLive.postValue(true)
                sendClientScanState(true)
            }
        }
    }

    override fun onStart() {
        super.onStart()
        bluetoothManager =
            this@MainActivity.getSystemService(BluetoothManager::class.java)
        bluetoothAdapter = bluetoothManager.adapter
    }

    override fun onResume() {
        super.onResume()
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            // Bluetooth is not supported or not enabled
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            startActivityForResult(enableBtIntent, 1)
        }

        ClientManager.get().connStateLive.observe(this) {
            if (it != null) {
                when (it) {
                    ClientConnectState.CONNECTED -> {
                        sendClientConnectState(ClientConnectState.CONNECTED.name)
                    }
                    ClientConnectState.CONNECTING -> {
                        sendClientConnectState(ClientConnectState.CONNECTING.name)
                    }
                    ClientConnectState.IDLE -> {
                        sendClientConnectState(ClientConnectState.IDLE.name)
                    }
                }
            }
        }

        ServerManager.instance.serverConnectStateLive.observe(this){
            if (it != null) {
                when (it) {
                    ServerConnectState.CONNECTED -> {
                        sendServerConnectState(ServerConnectState.CONNECTED.name)
                    }
                    ServerConnectState.STARTING -> {
                        sendServerConnectState(ServerConnectState.STARTING.name)
                    }
                    ServerConnectState.STOP -> {
                        sendServerConnectState(ServerConnectState.STOP.name)
                    }
                }
            }
        }
    }

    override fun onPause() {
        super.onPause()
        ClientManager.get().connStateLive.removeObservers(this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_FOUND))
        registerReceiver(receiver, IntentFilter(BluetoothAdapter.ACTION_DISCOVERY_FINISHED))
        registerReceiver(receiver, IntentFilter(BluetoothAdapter.ACTION_DISCOVERY_STARTED))
    }
    private val methodCallHandler = MethodCallHandler { call, result ->
        when (call.method) {
            "scan" -> {
                if (ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.BLUETOOTH_SCAN
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    bluetoothAdapter.startDiscovery();
                    result.success(null)
                } else {
                    result.error("PERMISSION_DENIED", "Bluetooth scan permission denied", null)
                }
                discoveredDevices.clear() // Clear previous scan results
                sendScanResults(discoveredDevices)

            }
            "stopScan" -> {
                if (ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.BLUETOOTH_SCAN
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    bluetoothAdapter.cancelDiscovery()
                    result.success(null)
                } else {
                    result.error("PERMISSION_DENIED", "Bluetooth scan permission denied", null)
                }
            }

            "connectAsClient" -> {
                imServer = false
                val deviceId: String = call.argument<String>("deviceId") ?: ""
                if (deviceId.isEmpty()) {
                    result.error("INVALID_ARGUMENT", "Device ID is required", null)
                    return@MethodCallHandler
                }

                if (bluetoothAdapter?.isEnabled == false) {
                    val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    startActivityForResult(enableBtIntent, 1)
                    return@MethodCallHandler
                }

                ClientManager.get().init(bluetoothManager)
                ClientManager.get().connectAsClient(deviceId)
                result.success(null)
            }

            "connectAsServer" -> {
                imServer = true
                val bluetoothManager: BluetoothManager =
                    this@MainActivity.getSystemService(BluetoothManager::class.java)
                val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.getAdapter()
                if (bluetoothAdapter?.isEnabled == false) {

                    val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    startActivityForResult(enableBtIntent, 1)

                    return@MethodCallHandler
                }

                // Make the device discoverable for 300 seconds (5 minutes)
                val requestCode = 1;
                val discoverableIntent: Intent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                    putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 300)
                }
                startActivityForResult(discoverableIntent, requestCode)

                ServerManager.instance.startServer()
                result.success(null)
            }

            "serverStop" -> {
                imServer = false
                ServerManager.instance.stopServer()
                result.success(null)
            }

            "disconnect" -> {
                val deviceId = call.argument<String>("deviceId")
                if(imServer){
                    ServerManager.instance.stopServer()
                } else {
                    if (deviceId.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "Device ID is required", null)
                        return@MethodCallHandler
                    }
                    ClientManager.get().disconnect()
                }
                result.success(null)
            }

            "sendData" -> {
                val data = call.argument<String>("data")
                if (data != null) {
                    // Here you would handle sending the data
                    result.success("Data sent: $data")
                } else {
                    result.error("INVALID_ARGUMENT", "Data argument is required", null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "channel.whiles.app/bluetooth")
        methodChannel?.setMethodCallHandler(methodCallHandler)
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(receiver)
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }

    fun sendScanResults(list: List<Map<String, String>>) {
        methodChannel?.invokeMethod("scanResults", list)

    }

    fun sendClientConnectState(state: String) {
        methodChannel?.invokeMethod("clientConnectState", state)
    }

    fun sendClientScanState(state: Boolean) {
        methodChannel?.invokeMethod("clientScanState", state)
    }

    fun sendServerConnectState(state: String) {
        methodChannel?.invokeMethod("serverConnectState", state)
    }
}
