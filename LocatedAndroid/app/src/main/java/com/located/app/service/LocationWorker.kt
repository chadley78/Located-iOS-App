package com.located.app.service

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.firebase.auth.FirebaseAuth
import com.located.app.data.model.LocationData
import com.located.app.data.repository.LocationRepository
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.tasks.await
import java.util.UUID

@HiltWorker
class LocationWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters,
    private val locationRepository: LocationRepository
) : CoroutineWorker(appContext, workerParams) {

    private val fusedClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(appContext)

    override suspend fun doWork(): Result {
        return try {
            val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return Result.success()
            val location = getCurrentLocation() ?: return Result.retry()

            val data = LocationData.create(
                id = UUID.randomUUID().toString(),
                userId = userId,
                latitude = location.latitude,
                longitude = location.longitude,
                accuracy = location.accuracy,
                altitude = location.altitude,
                speed = location.speed,
                bearing = location.bearing,
                timestamp = java.util.Date(location.time),
                isBackgroundUpdate = true
            )

            locationRepository.saveLocation(data)
                .onFailure { return Result.retry() }
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    private suspend fun getCurrentLocation(): android.location.Location? {
        return try {
            val token = CancellationTokenSource()
            fusedClient.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, token.token).await()
        } catch (_: Exception) {
            null
        }
    }
}
