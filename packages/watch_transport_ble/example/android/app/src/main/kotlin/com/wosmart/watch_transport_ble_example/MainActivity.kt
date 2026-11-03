package com.wosmart.watch_transport_ble_example

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "watch_transport_ble_example/platform")
            .setMethodCallHandler { call, result ->
                if (call.method == "androidSdk") result.success(Build.VERSION.SDK_INT)
                else result.notImplemented()
            }
    }
}
