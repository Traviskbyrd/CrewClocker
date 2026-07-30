package com.tbyrd.crewclocker.data

import com.tbyrd.crewclocker.data.models.TimeEntry
import com.tbyrd.crewclocker.data.models.ClockOutUpdate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class TimeEntryRepository {
    private val postgrest = SupabaseClient.postgrest

    // Inserts a new time entry into Supabase (Clock-in)
    suspend fun insertTimeEntry(timeEntry: TimeEntry) = withContext(Dispatchers.IO) {
        postgrest.from("time_entries")
            .insert(timeEntry)
    }

    // Updates an active (non-clocked-out) time entry with the clock-out timestamp (Clock-out)
    suspend fun clockOut(crewId: String, jobId: String, clockOutTime: String) = withContext(Dispatchers.IO) {
        postgrest.from("time_entries")
            .update(ClockOutUpdate(clock_out = clockOutTime)) {
                filter {
                    eq("crew_id", crewId)
                    eq("job_id", jobId)
                    exact("clock_out", null)
                }
            }
    }
}
