package com.tbyrd.crewclocker.data.models

import kotlinx.serialization.Serializable

@Serializable
data class Job(
    val id: String,
    val name: String,
    val address: String? = null,
    val lat: Double,
    val lng: Double,
    val radius_meters: Int = 100,
    val status: String = "active"
)
