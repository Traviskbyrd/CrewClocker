package com.tbyrd.crewclocker.services

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.tbyrd.crewclocker.data.JobRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

// LocationTrackingService: The "brain" of the app.
// Runs in the background to monitor geofences and auto-trigger clock-ins/outs.
class LocationTrackingService : Service() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var geofencingClient: GeofencingClient
    private val jobRepository = JobRepository()

    companion object {
        private const val TAG = "LocationTrackingService"
        private const val CHANNEL_ID = "CrewClockerGeofencingChannel"
        private const val NOTIFICATION_ID = 1001
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "LocationTrackingService onCreate")
        geofencingClient = LocationServices.getGeofencingClient(this)
        startForegroundServiceNotification()
        registerGeofences()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "LocationTrackingService onStartCommand")
        // Ensure the service runs persistently and handles location updates
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "LocationTrackingService onDestroy")
        // Clean up resources
        serviceScope.cancel()
    }

    /**
     * Set up a low-importance notification channel and start the service in the foreground.
     * This is required on Android 8.0+ for persistent background executions.
     */
    private fun startForegroundServiceNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CrewClocker Location Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors background geofences for clock-in/out automation"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CrewClocker Active")
            .setContentText("Monitoring job sites for automated clock-in/out.")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    /**
     * Fetches active jobs from the repository and registers them as Google Play Services Geofences.
     */
    private fun registerGeofences() {
        serviceScope.launch {
            try {
                val jobs = jobRepository.getActiveJobs()
                if (jobs.isEmpty()) {
                    Log.d(TAG, "No active jobs found to register for geofencing.")
                    return@launch
                }

                val geofenceList = jobs.map { job ->
                    Geofence.Builder()
                        .setRequestId(job.id)
                        .setCircularRegion(job.lat, job.lng, job.radius_meters.toFloat())
                        .setExpirationDuration(Geofence.NEVER_EXPIRE)
                        .setTransitionTypes(
                            Geofence.GEOFENCE_TRANSITION_ENTER or 
                            Geofence.GEOFENCE_TRANSITION_EXIT or 
                            Geofence.GEOFENCE_TRANSITION_DWELL
                        )
                        .setLoiteringDelay(30000) // 30 seconds loitering delay for DWELL trigger
                        .build()
                }

                val geofencingRequest = GeofencingRequest.Builder()
                    .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                    .addGeofences(geofenceList)
                    .build()

                if (ActivityCompat.checkSelfPermission(
                        this@LocationTrackingService,
                        Manifest.permission.ACCESS_FINE_LOCATION
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    Log.e(TAG, "ACCESS_FINE_LOCATION is not granted. Cannot register geofences.")
                    return@launch
                }

                val intent = Intent(this@LocationTrackingService, GeofenceBroadcastReceiver::class.java)
                val pendingIntent = PendingIntent.getBroadcast(
                    this@LocationTrackingService,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )

                geofencingClient.addGeofences(geofencingRequest, pendingIntent).run {
                    addOnSuccessListener {
                        Log.d(TAG, "Successfully registered ${geofenceList.size} geofences.")
                    }
                    addOnFailureListener { e ->
                        Log.e(TAG, "Failed to register geofences: ${e.message}", e)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error while registering geofences: ${e.message}", e)
            }
        }
    }
}
