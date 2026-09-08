package com.tbyrd.crewclocker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.tbyrd.crewclocker.tracking.TrackingChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TrackingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
