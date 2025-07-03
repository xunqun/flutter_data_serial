package app.whiles.serial.flutter_data_serial

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import app.whiles.serial.flutter_data_serial.manager.ClientManager
import app.whiles.serial.flutter_data_serial.manager.ServerManager
import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.IntentFilter
import androidx.annotation.RequiresPermission
import androidx.lifecycle.LifecycleOwner
import app.whiles.serial.flutter_data_serial.constant.ClientConnectState
import app.whiles.serial.flutter_data_serial.constant.ServerConnectState

class NativeChannel : FlutterPlugin, ActivityAware {
    private var activity: Activity? = null
    private var methodChannel: MethodChannel? = null
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    var imServer = false
    private val discoveredDevices: MutableList<HashMap<String, String>> = mutableListOf()

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


    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    fun attachToActivity(activity: Activity) {
        this.activity = activity
        bluetoothManager = activity.getSystemService(BluetoothManager::class.java)
        bluetoothAdapter = bluetoothManager?.adapter
        register()
        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
            // Bluetooth is not supported or not enabled
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            this.activity?.startActivityForResult(enableBtIntent, 1)
        }
    }

    private fun register() {
        this.activity?.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_FOUND))
        this.activity?.registerReceiver(receiver, IntentFilter(BluetoothAdapter.ACTION_DISCOVERY_FINISHED))
        this.activity?.registerReceiver(receiver, IntentFilter(BluetoothAdapter.ACTION_DISCOVERY_STARTED))

        ClientManager.get().connStateLive.observe(this.activity!! as LifecycleOwner) {
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



        ServerManager.get().serverConnectStateLive.observe(this.activity as LifecycleOwner){
            if (it != null) {
                when (it) {
                    ServerConnectState.CONNECTED -> {
                        sendServerConnectState(ServerConnectState.CONNECTED.name)
                    }
                    ServerConnectState.STARTING -> {
                        sendServerConnectState(ServerConnectState.STARTING.name)
                    }
                    ServerConnectState.STOPPED -> {
                        sendServerConnectState(ServerConnectState.STOPPED.name)
                    }
                }
            }
        }

        ClientManager.get().receivedDataLive.observe(this.activity as LifecycleOwner) { data ->
            if (data != null) {
                sendClientReceivedData(data)
            }
        }

        ServerManager.get().receivedDataLive.observe(this.activity as LifecycleOwner) { data ->
            if (data != null) {
                sendServerReceivedData(data)
            }
        }
    }

    fun detachFromActivity() {
        this.activity = null
        activity?.unregisterReceiver(receiver)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "channel.whiles.app/bluetooth")
        methodChannel?.setMethodCallHandler(methodCallHandler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachToActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachFromActivity()
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachToActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        detachFromActivity()
    }

    @androidx.annotation.RequiresPermission(android.Manifest.permission.BLUETOOTH_SCAN)
    private val methodCallHandler = MethodChannel.MethodCallHandler  { call, result ->
        val act: Activity = activity!!
        when (call.method) {
            "scan" -> {
                if (ActivityCompat.checkSelfPermission(
                        act as Context,
                        Manifest.permission.BLUETOOTH_SCAN
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    bluetoothAdapter?.startDiscovery()
                    result.success(null)
                } else {
                    result.error("PERMISSION_DENIED", "Bluetooth scan permission denied", null)
                }
                discoveredDevices.clear()
                sendScanResults(discoveredDevices)
            }
            "stopScan" -> {
                if (ActivityCompat.checkSelfPermission(
                        act as Context,
                        Manifest.permission.BLUETOOTH_SCAN
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    bluetoothAdapter?.cancelDiscovery()
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

                } else if (bluetoothAdapter?.isEnabled == false) {
                    val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    act.startActivityForResult(enableBtIntent, 1)
                } else {
                    ClientManager.get().init(bluetoothManager!!)
                    ClientManager.get().connectAsClient(deviceId)
                    result.success(null)
                }
            }
            "connectAsServer" -> {
                imServer = true
                val manager = bluetoothManager ?: act.getSystemService(BluetoothManager::class.java)
                val adapter = manager.adapter
                if (adapter?.isEnabled == false) {
                    val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    act.startActivityForResult(enableBtIntent, 1)
                } else {
                    val requestCode = 1
                    val discoverableIntent =
                        Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                            putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 300)
                        }
                    act.startActivityForResult(discoverableIntent, requestCode)
                    ServerManager.get().startServer()
                    result.success(null)
                }
            }
            "serverStop" -> {
                imServer = false
                ServerManager.get().stopServer()
                result.success(null)
            }
            "disconnect" -> {
                ClientManager.get().disconnect()
                result.success(null)
            }
            "sendData" -> {
                val data = call.argument<ByteArray>("data")
                if (data != null) {
                    result.success(null)
                    ClientManager.get().sendDataToServer(data)
                } else {
                    result.error("INVALID_ARGUMENT", "Data argument is required", null)
                }
            }
            "serverSendData" -> {
                if (!imServer) {
                    result.error("NOT_SERVER", "This method can only be called when connected as a server", null)
                    return@MethodCallHandler
                }
                val data = call.argument<ByteArray>("data")
                if (data != null) {
                    result.success(null)
                    ServerManager.get().sendData(data)
                } else {
                    result.error("INVALID_ARGUMENT", "Data argument is required", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
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

    fun sendServerReceivedData(data: ByteArray) {
        methodChannel?.invokeMethod("serverReceivedData", data)
    }

    fun sendClientReceivedData(data: ByteArray) {
        methodChannel?.invokeMethod("clientReceivedData", data)
    }
}