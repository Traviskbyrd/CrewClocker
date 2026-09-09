package com.tbyrd.crewclocker.tracking

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONArray

object Monitoring {
    fun intent(context: Context): PendingIntent = PendingIntent.getBroadcast(context, 0,
        Intent(context, GeofenceReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or
        (if(Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0))
    fun permitted(c: Context): Boolean = ContextCompat.checkSelfPermission(c, Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED &&
        (Build.VERSION.SDK_INT<29 || ContextCompat.checkSelfPermission(c, Manifest.permission.ACCESS_BACKGROUND_LOCATION)==PackageManager.PERMISSION_GRANTED)
    fun request(sites: JSONArray, generation: String): GeofencingRequest {
        val fences = (0 until sites.length()).map { i ->
            val s=sites.getJSONObject(i)
            Geofence.Builder().setRequestId("$generation:${s.getString("assignment_id")}")
                .setCircularRegion(s.getDouble("lat"),s.getDouble("lng"),s.getDouble("radius_meters").toFloat())
                .setExpirationDuration(Geofence.NEVER_EXPIRE).setLoiteringDelay(120000)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_DWELL or Geofence.GEOFENCE_TRANSITION_EXIT).build()
        }
        return GeofencingRequest.Builder().setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER).addGeofences(fences).build()
    }
}

class RecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if(intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val p=context.getSharedPreferences("crewclocker_tracking",Context.MODE_PRIVATE)
        if(!p.getBoolean("enabled",false)) return
        p.edit().putInt("registered_sites",0).commit()
        if(!Monitoring.permitted(context)) {
            p.edit().putString("last_error","Open CrewClocker to restore location permissions.").commit(); return
        }
        val pending=goAsync()
        try {
            val sites=JSONArray(p.getString("sites","[]"))
            val generation=p.getString("generation",null) ?: error("No registration generation")
            LocationServices.getGeofencingClient(context).addGeofences(Monitoring.request(sites,generation),Monitoring.intent(context))
                .addOnSuccessListener { p.edit().putInt("registered_sites",sites.length()).remove("last_error").commit() }
                .addOnFailureListener { p.edit().putString("last_error","Restart recovery failed. Open CrewClocker and enable monitoring again.").commit() }
                .addOnCompleteListener { pending.finish() }
        } catch(e: Exception) {
            p.edit().putString("last_error","Restart recovery failed. Open CrewClocker.").commit(); pending.finish()
        }
    }
}
