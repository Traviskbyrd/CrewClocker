package com.tbyrd.crewclocker.services

import android.app.Service
import android.content.Intent
import android.os.IBinder

// LocationTrackingService: The "brain" of the app.
// Runs in the background to monitor geofences and auto-trigger clock-ins/outs.
class LocationTrackingService : Service() {

    override fun onCreate() {
        super.onCreate()
        // Initialize GeofencingClient and Location services here
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Ensure the service runs persistently and handles location updates
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up resources
    }
}
