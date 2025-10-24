package com.located.app.service

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.located.app.data.model.LocationData
import com.located.app.data.repository.LocationRepository
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.tasks.await
import java.util.UUID

@HiltWorker
class LocationWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val locationRepository: LocationRepository
) : CoroutineWorker(context, params) {
    
    private val fusedLocationClient: FusedLocationProviderClient = 
        LocationServices.getFusedLocationProviderClient(context)
    
    override suspend fun doWork(): Result {
        return try {
            println("📍 LocationWorker: Starting periodic location update")
            
            // Get current location
            val location = getCurrentLocation()
            if (location != null) {
                // Save location to Firestore
                val locationData = LocationData.create(
                    id = UUID.randomUUID().toString(),
                    userId = "temp_user_id", // TODO: Get from AuthRepository
                    latitude = location.latitude,
                    longitude = location.longitude,
                    accuracy = location.accuracy,
                    altitude = location.altitude,
                    speed = location.speed,
                    bearing = location.bearing,
                    timestamp = java.util.Date(location.time),
                    isBackgroundUpdate = true
                )
                
                locationRepository.saveLocation(locationData).onSuccess {
                    println("✅ LocationWorker: Location saved successfully")
                }.onFailure { error ->
                    println("❌ LocationWorker: Failed to save location: ${error.message}")
                }
                
                Result.success()
            } else {
                println("❌ LocationWorker: Failed to get current location")
                Result.retry()
            }
        } catch (e: Exception) {
            println("❌ LocationWorker: Error: ${e.message}")
            Result.failure()
        }
    }
    
    private suspend fun getCurrentLocation(): android.location.Location? {
        return try {
            val cancellationTokenSource = CancellationTokenSource()
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                cancellationTokenSource.token
            ).await()
        } catch (e: Exception) {
            println("❌ LocationWorker: Error getting location: ${e.message}")
            null
        }
    }
}
