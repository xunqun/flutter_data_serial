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
import android.util.Log
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NativeChannel())
    }


}
