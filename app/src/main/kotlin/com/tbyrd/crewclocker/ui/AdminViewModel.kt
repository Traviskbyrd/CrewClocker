package com.tbyrd.crewclocker.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tbyrd.crewclocker.data.JobRepository
import com.tbyrd.crewclocker.data.models.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import com.google.android.gms.maps.model.LatLng

class AdminViewModel(private val repository: JobRepository) : ViewModel() {

    private val _activeJobs = MutableStateFlow<List<Job>>(emptyList())
    val activeJobs: StateFlow<List<Job>> = _activeJobs.asStateFlow()

    init {
        viewModelScope.launch {
            _activeJobs.value = repository.getActiveJobs()
        }
    }

    // Saves a new job site from the map
    fun createNewJob(name: String, latLng: LatLng, address: String) {
        viewModelScope.launch {
            val newJob = Job(
                id = java.util.UUID.randomUUID().toString(),
                name = name,
                address = address,
                lat = latLng.latitude,
                lng = latLng.longitude
            )
            repository.saveJob(newJob) 
        }
    }
}
