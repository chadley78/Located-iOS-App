package com.located.app.presentation.location

import android.Manifest
import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.located.app.service.LocationService
import com.located.app.service.LocationWorker
import androidx.work.*
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class LocationViewModel @Inject constructor(
    application: Application
) : AndroidViewModel(application) {

    private val context: Context = application.applicationContext

    private val _uiState = MutableStateFlow(LocationUiState())
    val uiState: StateFlow<LocationUiState> = _uiState.asStateFlow()

    fun refreshPermissions() {
        _uiState.value = _uiState.value.copy(
            hasFine = hasPermission(Manifest.permission.ACCESS_FINE_LOCATION),
            hasCoarse = hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION),
            hasBackground = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            } else true
        )
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    fun startLocationTracking() {
        viewModelScope.launch {
            val intent = Intent(context, LocationService::class.java)
            ContextCompat.startForegroundService(context, intent)
            _uiState.value = _uiState.value.copy(trackingEnabled = true)

            // Schedule periodic background updates every 15 minutes
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            val work = PeriodicWorkRequestBuilder<LocationWorker>(15, java.util.concurrent.TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "location_worker",
                ExistingPeriodicWorkPolicy.UPDATE,
                work
            )
        }
    }

    fun stopLocationTracking() {
        viewModelScope.launch {
            val intent = Intent(context, LocationService::class.java)
            context.stopService(intent)
            _uiState.value = _uiState.value.copy(trackingEnabled = false)
            WorkManager.getInstance(context).cancelUniqueWork("location_worker")
        }
    }

    fun openBatteryOptimizationSettings() {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}

data class LocationUiState(
    val hasFine: Boolean = false,
    val hasCoarse: Boolean = false,
    val hasBackground: Boolean = false,
    val trackingEnabled: Boolean = false
)
