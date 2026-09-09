package com.tbyrd.crewclocker.tracking

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class TrackingChannel(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val prefs=activity.getSharedPreferences("crewclocker_tracking",Context.MODE_PRIVATE)
    private val client=LocationServices.getGeofencingClient(activity)
    private var permissionResult: MethodChannel.Result?=null
    private var changing=false
    init { MethodChannel(messenger,"com.tbyrd.crewclocker/tracking").setMethodCallHandler(this) }
    private fun allowed(p: String)=ContextCompat.checkSelfPermission(activity,p)==PackageManager.PERMISSION_GRANTED
    fun onPermissionResult(code: Int) {
        if(code==8401) { permissionResult?.success(null); permissionResult=null }
    }
    override fun onMethodCall(call: MethodCall,result: MethodChannel.Result) {
        try {
            when(call.method) {
                "health" -> {
                    val location=activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    result.success(mapOf("fineLocation" to allowed(Manifest.permission.ACCESS_FINE_LOCATION),
                        "backgroundLocation" to (Build.VERSION.SDK_INT<29 || allowed(Manifest.permission.ACCESS_BACKGROUND_LOCATION)),
                        "locationServices" to (if(Build.VERSION.SDK_INT>=28) location.isLocationEnabled else (location.isProviderEnabled(LocationManager.GPS_PROVIDER) || location.isProviderEnabled(LocationManager.NETWORK_PROVIDER))),
                        "enabled" to prefs.getBoolean("enabled",false), "registeredSites" to prefs.getInt("registered_sites",0),
                        "lastError" to prefs.getString("last_error",null), "employeeId" to prefs.getString("employee_id",null),
                        "pendingEvents" to EventJournal(activity).use { it.count() }))
                }
                "requestForegroundPermission" -> {
                    if(permissionResult!=null) { result.error("BUSY","Permission request already open",null); return }
                    permissionResult=result
                    ActivityCompat.requestPermissions(activity,arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION),8401)
                }
                "openSettings" -> { activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:${activity.packageName}"))); result.success(null) }
                "currentLocation" -> {
                    if(!allowed(Manifest.permission.ACCESS_FINE_LOCATION)) { result.error("PERMISSION_REQUIRED","Allow precise location first",null); return }
                    val request=CurrentLocationRequest.Builder().setPriority(Priority.PRIORITY_HIGH_ACCURACY).setDurationMillis(20000).setMaxUpdateAgeMillis(15000).build()
                    LocationServices.getFusedLocationProviderClient(activity).getCurrentLocation(request,CancellationTokenSource().token)
                        .addOnSuccessListener { location ->
                            if(location==null) result.error("NO_LOCATION","No location fix. Try outdoors or place the map pin manually.",null)
                            else result.success(mapOf("lat" to location.latitude,"lng" to location.longitude,"accuracy" to location.accuracy))
                        }.addOnFailureListener { result.error("LOCATION_FAILED","Could not read location",null) }
                }
                "pending" -> result.success(EventJournal(activity).use { it.pending() })
                "acknowledge" -> { EventJournal(activity).use { it.acknowledge(call.argument<List<String>>("ids").orEmpty()) }; result.success(null) }
                "stop" -> {
                    if(changing) { result.error("BUSY","Monitoring is changing. Try again.",null); return }
                    changing=true
                    // Stop capture before asynchronous removal; retain owner binding and journal.
                    prefs.edit().putBoolean("enabled",false).putInt("registered_sites",0).commit()
                    client.removeGeofences(Monitoring.intent(activity)).addOnSuccessListener { changing=false; result.success(null) }
                        .addOnFailureListener { changing=false; result.error("STOP_FAILED","Capture paused but unregister failed. Retry stop.",null) }
                }
                "register" -> register(call,result)
                else -> result.notImplemented()
            }
        } catch(e: Exception) { result.error("TRACKING_ERROR",e.message,null) }
    }
    private fun register(call: MethodCall,result: MethodChannel.Result) {
        if(changing) { result.error("BUSY","Monitoring is changing",null); return }
        if(!Monitoring.permitted(activity)) { result.error("PERMISSION_REQUIRED","Precise and background location are required",null); return }
        val employee=call.argument<String>("employeeId") ?: error("Employee required")
        UUID.fromString(employee)
        val sites=call.argument<List<Map<String,Any>>>("sites").orEmpty()
        require(sites.size in 1..100)
        val previous=prefs.getString("employee_id",null)
        require(!(prefs.getBoolean("enabled",false) && previous!=employee)) { "Stop monitoring for the previous account first" }
        require(!EventJournal(activity).use { it.hasOtherOwner(employee) }) { "Sync previous account observations before switching" }
        val assignments=mutableSetOf<String>()
        sites.forEach { s ->
            UUID.fromString(s["id"] as String)
            UUID.fromString(s["assignment_id"] as String)
            require(assignments.add(s["assignment_id"] as String))
            require((s["assignment_version"] as Number).toInt()>0)
            require((s["lat"] as Number).toDouble() in -90.0..90.0)
            require((s["lng"] as Number).toDouble() in -180.0..180.0)
            require((s["radius_meters"] as Number).toDouble() in 100.0..1000.0)
        }
        val json=JSONArray(sites.map { JSONObject(it) })
        val generation=UUID.randomUUID().toString()
        val request=Monitoring.request(json,generation)
        changing=true
        prefs.edit().putBoolean("enabled",false).putInt("registered_sites",0).commit()
        client.removeGeofences(Monitoring.intent(activity)).addOnSuccessListener {
            val device=prefs.getString("device_id",null) ?: UUID.randomUUID().toString()
            prefs.edit().putString("device_id",device).putString("employee_id",employee).putString("sites",json.toString())
                .putString("generation",generation).putBoolean("enabled",true).commit()
            client.addGeofences(request,Monitoring.intent(activity)).addOnSuccessListener {
                changing=false; prefs.edit().putInt("registered_sites",sites.size).remove("last_error").commit(); result.success(null)
            }.addOnFailureListener {
                changing=false; prefs.edit().putBoolean("enabled",false).putInt("registered_sites",0).putString("last_error","Registration failed. Retry monitoring setup.").commit()
                result.error("REGISTRATION_FAILED","Unable to register assigned sites",null)
            }
        }.addOnFailureListener { changing=false; result.error("REGISTRATION_FAILED","Unable to replace registered sites",null) }
    }
}
