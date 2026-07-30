package com.tbyrd.crewclocker.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingEvent
import com.tbyrd.crewclocker.data.SupabaseClient
import com.tbyrd.crewclocker.data.TimeEntryRepository
import com.tbyrd.crewclocker.data.models.TimeEntry
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import java.util.UUID

class GeofenceBroadcastReceiver : BroadcastReceiver() {

    private val timeEntryRepository = TimeEntryRepository()

    companion object {
        private const val TAG = "GeofenceReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Geofence transition received!")
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        if (geofencingEvent == null) {
            Log.e(TAG, "GeofencingEvent is null")
            return
        }

        if (geofencingEvent.hasError()) {
            val errorMessage = GeofenceStatusCodes.getStatusCodeString(geofencingEvent.errorCode)
            Log.e(TAG, "GeofencingEvent error: $errorMessage")
            return
        }

        val geofenceTransition = geofencingEvent.geofenceTransition
        val triggeringGeofences = geofencingEvent.triggeringGeofences ?: emptyList()

        if (triggeringGeofences.isEmpty()) {
            Log.d(TAG, "No triggering geofences found in the event.")
            return
        }

        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Fetch active user ID from Supabase Auth or use fallback test ID
                val crewId = SupabaseClient.auth.currentSessionOrNull()?.user?.id ?: "test-crew-id-123"
                val currentTimeString = Instant.now().toString()

                for (geofence in triggeringGeofences) {
                    val jobId = geofence.requestId
                    when (geofenceTransition) {
                        Geofence.GEOFENCE_TRANSITION_ENTER, Geofence.GEOFENCE_TRANSITION_DWELL -> {
                            Log.d(TAG, "ENTER/DWELL transition detected for job: $jobId")
                            val newTimeEntry = TimeEntry(
                                id = UUID.randomUUID().toString(),
                                crew_id = crewId,
                                job_id = jobId,
                                clock_in = currentTimeString,
                                clock_out = null
                            )
                            timeEntryRepository.insertTimeEntry(newTimeEntry)
                            Log.d(TAG, "Clocked in successfully for job: $jobId")
                        }
                        Geofence.GEOFENCE_TRANSITION_EXIT -> {
                            Log.d(TAG, "EXIT transition detected for job: $jobId")
                            timeEntryRepository.clockOut(crewId, jobId, currentTimeString)
                            Log.d(TAG, "Clocked out successfully for job: $jobId")
                        }
                        else -> {
                            Log.e(TAG, "Unknown geofence transition type: $geofenceTransition")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error handling geofence transition: ${e.message}", e)
            } finally {
                pendingResult.finish()
            }
        }
    }
}
