package com.tbyrd.crewclocker.data

import com.tbyrd.crewclocker.data.models.Job
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class JobRepository {
    private val supabase = SupabaseClient.postgrest

    // Fetches only 'active' jobs to keep the UI clean
    suspend fun getActiveJobs(): List<Job> = withContext(Dispatchers.IO) {
        supabase.from("jobs")
            .select {
                filter {
                    eq("status", "active")
                }
            }
            .decodeList<Job>()
    }

    // Inserts a new job site into Supabase
    suspend fun saveJob(job: Job) = withContext(Dispatchers.IO) {
        supabase.from("jobs")
            .insert(job)
    }
}
