package com.tbyrd.crewclocker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.tbyrd.crewclocker.tracking.TrackingChannel

class MainActivity : FlutterActivity() {
    private var tracking: TrackingChannel? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tracking = TrackingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        tracking?.onPermissionResult(requestCode)
    }
}
