package com.tbyrd.crewclocker.data.models

import kotlinx.serialization.Serializable

@Serializable
data class TimeEntry(
    val id: String,
    val crew_id: String,
    val job_id: String,
    val clock_in: String,
    val clock_out: String? = null
)

@Serializable
data class ClockOutUpdate(
    val clock_out: String
)
