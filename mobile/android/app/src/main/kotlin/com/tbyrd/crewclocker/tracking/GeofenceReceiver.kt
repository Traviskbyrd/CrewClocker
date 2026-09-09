package com.tbyrd.crewclocker.tracking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import org.json.JSONArray

class GeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        val p = context.getSharedPreferences("crewclocker_tracking", Context.MODE_PRIVATE)
        if (!p.getBoolean("enabled", false)) return
        if (event.hasError()) {
            p.edit().putString("last_error", "Geofence error ${event.errorCode}").putInt("registered_sites",0).commit()
            return
        }
        val transition = when(event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "enter"
            Geofence.GEOFENCE_TRANSITION_DWELL -> "dwell"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "exit"
            else -> return
        }
        try {
            val employee = p.getString("employee_id", null) ?: return
            val device = p.getString("device_id", null) ?: return
            val generation = p.getString("generation", null) ?: return
            val requested = event.triggeringGeofences.orEmpty().map { it.requestId }.toSet()
            val sites = JSONArray(p.getString("sites", "[]"))
            val matches = (0 until sites.length()).map { sites.getJSONObject(it) }.filter {
                requested.contains("$generation:${it.getString("assignment_id")}")
            }
            // Ignore callbacks from an old assignment/device-owner generation.
            if (matches.isNotEmpty()) EventJournal(context).use { it.append(employee, device, matches, transition) }
        } catch (e: Exception) {
            p.edit().putString("last_error", "Local capture failed: ${e.javaClass.simpleName}").commit()
        }
    }
}
