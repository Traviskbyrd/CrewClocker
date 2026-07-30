package com.tbyrd.crewclocker.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxSize
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import com.google.android.gms.maps.model.CameraPosition

// AdminMapView: The core administrative tool for managing job sites via Map API
@Composable
fun AdminMapView(viewModel: AdminViewModel, onLocationSelected: (LatLng) -> Unit) {
    // Starting position: Austin, TX (Travis's home base)
    val austin = LatLng(30.2672, -97.7431)
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(austin, 12f)
    }

    GoogleMap(
        modifier = androidx.compose.ui.Modifier.fillMaxSize(),
        cameraPositionState = cameraPositionState,
        onMapClick = { latLng ->
            // Triggered when admin pins a new location
            onLocationSelected(latLng)
        }
    ) {
        // Observe jobs from ViewModel
        val jobs = viewModel.activeJobs.collectAsState().value
        jobs.forEach { job ->
            Marker(
                state = MarkerState(position = LatLng(job.lat, job.lng)),
                title = job.name
            )
        }
    }
}
