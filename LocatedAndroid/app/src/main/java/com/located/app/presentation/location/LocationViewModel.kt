package com.located.app.presentation.location

import android.Manifest
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.work.*
import com.google.android.gms.location.*
import com.located.app.data.model.LocationData
import com.located.app.data.repository.LocationRepository
import com.located.app.service.LocationService
import com.located.app.service.LocationWorker
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit
import javax.inject.Inject

@HiltViewModel
class LocationViewModel @Inject constructor(
    application: Application,
    private val locationRepository: LocationRepository
) : AndroidViewModel(application) {
    
    private val context = application.applicationContext
    private val fusedLocationClient: FusedLocationProviderClient = 
        LocationServices.getFusedLocationProviderClient(context)
    private val workManager = WorkManager.getInstance(context)
    
    private val _uiState = MutableStateFlow(LocationUiState())
    val uiState: StateFlow<LocationUiState> = _uiState.asStateFlow()
    
    // Permission status
    fun checkLocationPermissions(): LocationPermissionStatus {
        val fineLocationPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        
        val coarseLocationPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        
        val backgroundLocationPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Background location permission not required for older versions
        }
        
        return LocationPermissionStatus(
            fineLocation = fineLocationPermission,
            coarseLocation = coarseLocationPermission,
            backgroundLocation = backgroundLocationPermission
        )
    }
    
    fun updatePermissionStatus() {
        val permissionStatus = checkLocationPermissions()
        _uiState.value = _uiState.value.copy(
            permissionStatus = permissionStatus,
            isLocationSharingEnabled = permissionStatus.hasAllPermissions()
        )
    }
    
    fun startLocationTracking() {
        val permissionStatus = checkLocationPermissions()
        if (!permissionStatus.hasAllPermissions()) {
            _uiState.value = _uiState.value.copy(
                errorMessage = "Location permissions are required for tracking"
            )
            return
        }
        
        // Start foreground service
        val serviceIntent = Intent(context, LocationService::class.java)
        context.startForegroundService(serviceIntent)
        
        // Start WorkManager for periodic updates
        startPeriodicLocationUpdates()
        
        _uiState.value = _uiState.value.copy(
            isLocationSharingEnabled = true,
            errorMessage = null
        )
    }
    
    fun stopLocationTracking() {
        // Stop foreground service
        val serviceIntent = Intent(context, LocationService::class.java)
        context.stopService(serviceIntent)
        
        // Cancel WorkManager
        workManager.cancelUniqueWork("location_worker")
        
        _uiState.value = _uiState.value.copy(
            isLocationSharingEnabled = false
        )
    }
    
    private fun startPeriodicLocationUpdates() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(false) // Allow updates even with low battery
            .build()
        
        val locationWorkRequest = PeriodicWorkRequestBuilder<LocationWorker>(
            15, TimeUnit.MINUTES // Update every 15 minutes
        ).setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.LINEAR,
                WorkRequest.MIN_BACKOFF_MILLIS,
                TimeUnit.MILLISECONDS
            ).build()
        
        workManager.enqueueUniquePeriodicWork(
            "location_worker",
            ExistingPeriodicWorkPolicy.KEEP,
            locationWorkRequest
        )
    }
    
    fun requestLocationPermissions() {
        // This will be handled by the UI component
        _uiState.value = _uiState.value.copy(
            shouldRequestPermissions = true
        )
    }
    
    fun clearPermissionRequest() {
        _uiState.value = _uiState.value.copy(
            shouldRequestPermissions = false
        )
    }
    
    fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
        }
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }
    
    fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            try {
                context.startActivity(intent)
            } catch (e: Exception) {
                println("❌ Failed to open battery optimization settings: ${e.message}")
                // Fallback to general battery settings
                val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                fallbackIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(fallbackIntent)
            }
        }
    }
    
    fun getCurrentLocation() {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(isLoading = true)
                
                val location = getCurrentLocationSync()
                if (location != null) {
                    _uiState.value = _uiState.value.copy(
                        currentLocation = location,
                        isLoading = false
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        errorMessage = "Failed to get current location",
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    errorMessage = "Error getting location: ${e.message}",
                    isLoading = false
                )
            }
        }
    }
    
    private suspend fun getCurrentLocationSync(): Location? {
        return try {
            val cancellationTokenSource = CancellationTokenSource()
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY,
                cancellationTokenSource.token
            ).await()
        } catch (e: Exception) {
            println("❌ Error getting current location: ${e.message}")
            null
        }
    }
    
    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}

data class LocationUiState(
    val permissionStatus: LocationPermissionStatus = LocationPermissionStatus(),
    val isLocationSharingEnabled: Boolean = false,
    val currentLocation: Location? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val shouldRequestPermissions: Boolean = false
)

data class LocationPermissionStatus(
    val fineLocation: Boolean = false,
    val coarseLocation: Boolean = false,
    val backgroundLocation: Boolean = false
) {
    fun hasAllPermissions(): Boolean {
        return fineLocation && coarseLocation && backgroundLocation
    }
    
    fun hasBasicPermissions(): Boolean {
        return fineLocation && coarseLocation
    }
}
