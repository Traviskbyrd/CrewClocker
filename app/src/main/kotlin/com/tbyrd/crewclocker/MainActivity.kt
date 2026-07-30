package com.tbyrd.crewclocker

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.tbyrd.crewclocker.data.JobRepository
import com.tbyrd.crewclocker.ui.AdminMapView
import com.tbyrd.crewclocker.ui.AdminViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Instantiate the repository and view model
        val repository = JobRepository()
        val viewModel = AdminViewModel(repository)

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AdminMapView(
                        viewModel = viewModel,
                        onLocationSelected = { latLng ->
                            // When admin clicks/pins on the map, prompt or auto-create a new job site
                            val jobName = "Job Site ${System.currentTimeMillis() % 1000}"
                            val address = "Austin, TX"
                            
                            viewModel.createNewJob(jobName, latLng, address)
                            
                            Toast.makeText(
                                this@MainActivity,
                                "Created: $jobName at (${latLng.latitude}, ${latLng.longitude})",
                                Toast.LENGTH_SHORT
                            ).show()
                        }
                    )
                }
            }
        }
    }
}
