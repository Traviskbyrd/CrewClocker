package com.tbyrd.crewclocker.tracking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

/** No test identity, network call, or payroll mutation in a background callback. */
class GeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        val preferences = context.getSharedPreferences("crewclocker_tracking", Context.MODE_PRIVATE)
        if (event.hasError()) {
            preferences.edit().putString("last_error", "Geofence error ${event.errorCode}").commit()
            return
        }
        val employee = preferences.getString("employee_id", null) ?: return
        if (!preferences.getBoolean("enabled", false)) return
        val transition = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "enter"
            Geofence.GEOFENCE_TRANSITION_DWELL -> "dwell"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "exit"
            else -> return
        }
        try {
            EventJournal(context).use { journal ->
                journal.append(employee, event.triggeringGeofences.orEmpty().map { it.requestId }, transition)
            }
        } catch (error: Exception) {
            // Capture failure must become visible; never report a successful clock-in.
            preferences.edit().putString("last_error", "Local capture failed: ${error.javaClass.simpleName}").commit()
        }
    }
}
