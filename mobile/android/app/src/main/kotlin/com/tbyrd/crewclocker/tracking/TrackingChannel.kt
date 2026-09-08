package com.tbyrd.crewclocker.tracking

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TrackingChannel(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val prefs = activity.getSharedPreferences("crewclocker_tracking", Context.MODE_PRIVATE)
    private val client = LocationServices.getGeofencingClient(activity)
    init { MethodChannel(messenger, "com.tbyrd.crewclocker/tracking").setMethodCallHandler(this) }
    private fun allowed(permission: String) = ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
    private fun backgroundAllowed() = Build.VERSION.SDK_INT < 29 || allowed(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    private fun intent(): PendingIntent = PendingIntent.getBroadcast(activity, 0,
        Intent(activity, GeofenceReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or
          if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "health" -> {
                    val location = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    result.success(mapOf("fineLocation" to allowed(Manifest.permission.ACCESS_FINE_LOCATION),
                        "backgroundLocation" to backgroundAllowed(),
                        "locationServices" to (location.isProviderEnabled(LocationManager.GPS_PROVIDER) || location.isProviderEnabled(LocationManager.NETWORK_PROVIDER)),
                        "enabled" to prefs.getBoolean("enabled", false),
                        "registeredSites" to prefs.getInt("registered_sites", 0),
                        "lastError" to prefs.getString("last_error", null),
                        "pendingEvents" to EventJournal(activity).use { it.pending().size }))
                }
                "requestForegroundPermission" -> {
                    ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 8401)
                    result.success(null)
                }
                "openSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}")))
                    result.success(null)
                }
                "pending" -> result.success(EventJournal(activity).use { it.pending() })
                "acknowledge" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    EventJournal(activity).use { it.acknowledge(ids) }
                    result.success(null)
                }
                "stop" -> client.removeGeofences(intent()).addOnSuccessListener {
                    prefs.edit().putBoolean("enabled", false).putInt("registered_sites", 0).remove("employee_id").commit()
                    result.success(null)
                }.addOnFailureListener { result.error("STOP_FAILED", "Unable to unregister monitoring", null) }
                "register" -> register(call, result)
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("TRACKING_ERROR", error.message, null)
        }
    }
    private fun register(call: MethodCall, result: MethodChannel.Result) {
        if (!allowed(Manifest.permission.ACCESS_FINE_LOCATION) || !backgroundAllowed()) {
            result.error("PERMISSION_REQUIRED", "Precise and background location permission are required", null); return
        }
        val employee = call.argument<String>("employeeId")
        val sites = call.argument<List<Map<String, Any>>>("sites").orEmpty()
        if (employee.isNullOrBlank() || sites.isEmpty() || sites.size > 100) {
            result.error("INVALID_REGISTRATION", "Employee and 1–100 assigned sites are required", null); return
        }
        val previousEmployee = prefs.getString("employee_id", null)
        if (previousEmployee != null && previousEmployee != employee) {
            result.error("DEVICE_HANDOFF_REQUIRED", "Stop and reconcile the previous employee before switching", null); return
        }
        val fences = sites.map { site ->
            val id = site["id"] as String
            val lat = (site["lat"] as Number).toDouble()
            val lng = (site["lng"] as Number).toDouble()
            val radius = (site["radius_meters"] as Number).toFloat()
            require(id.isNotBlank() && lat in -90.0..90.0 && lng in -180.0..180.0 && radius in 100f..1000f)
            Geofence.Builder().setRequestId(id).setCircularRegion(lat, lng, radius)
                .setExpirationDuration(Geofence.NEVER_EXPIRE).setLoiteringDelay(120000)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_DWELL or Geofence.GEOFENCE_TRANSITION_EXIT).build()
        }
        // Registration is currently an explicit setup operation. Versioned updates,
        // boot recovery and assignment synchronization are required before rollout.
        client.removeGeofences(intent()).addOnSuccessListener {
            prefs.edit().putString("employee_id", employee).putBoolean("enabled", true).commit()
            client.addGeofences(GeofencingRequest.Builder().setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER).addGeofences(fences).build(), intent())
                .addOnSuccessListener {
                    prefs.edit().putInt("registered_sites", fences.size).remove("last_error").commit()
                    result.success(null)
                }.addOnFailureListener {
                    prefs.edit().putBoolean("enabled", false).putInt("registered_sites", 0).putString("last_error", "Registration failed").commit()
                    result.error("REGISTRATION_FAILED", "Unable to register job sites", null)
                }
        }.addOnFailureListener { result.error("REGISTRATION_FAILED", "Unable to replace job sites", null) }
    }
}
