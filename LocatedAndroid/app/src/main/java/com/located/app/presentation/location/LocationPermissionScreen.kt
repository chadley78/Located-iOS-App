package com.located.app.presentation.location

import android.Manifest
import android.os.Build
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.accompanist.permissions.*

@Composable
fun LocationPermissionScreen(
    viewModel: LocationViewModel = hiltViewModel(),
    onPermissionsGranted: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    
    // Permission state
    val locationPermissionState = rememberMultiplePermissionsState(
        permissions = listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
    )
    
    val backgroundLocationPermissionState = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        rememberPermissionState(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    } else {
        null
    }
    
    // Check permissions on first load
    LaunchedEffect(Unit) {
        viewModel.updatePermissionStatus()
    }
    
    // Handle permission results
    LaunchedEffect(locationPermissionState.allPermissionsGranted) {
        if (locationPermissionState.allPermissionsGranted) {
            // Request background location permission if needed
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                backgroundLocationPermissionState?.let { bgPermissionState ->
                    if (!bgPermissionState.status.isGranted) {
                        bgPermissionState.launchPermissionRequest()
                    }
                }
            } else {
                // All permissions granted for older versions
                viewModel.updatePermissionStatus()
                if (uiState.permissionStatus.hasAllPermissions()) {
                    onPermissionsGranted()
                }
            }
        }
    }
    
    LaunchedEffect(backgroundLocationPermissionState?.status) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            backgroundLocationPermissionState?.let { bgPermissionState ->
                if (bgPermissionState.status.isGranted) {
                    viewModel.updatePermissionStatus()
                    if (uiState.permissionStatus.hasAllPermissions()) {
                        onPermissionsGranted()
                    }
                }
            }
        }
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.LocationOn,
            contentDescription = "Location",
            modifier = Modifier.size(80.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = "Location Permission Required",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Located needs access to your location to keep your family connected and safe.",
            fontSize = 16.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        // Permission status cards
        PermissionStatusCard(
            title = "Basic Location Access",
            description = "Required for location sharing",
            isGranted = uiState.permissionStatus.hasBasicPermissions(),
            onRequestPermission = {
                locationPermissionState.launchMultiplePermissionRequest()
            }
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            PermissionStatusCard(
                title = "Background Location Access",
                description = "Required for continuous location tracking",
                isGranted = uiState.permissionStatus.backgroundLocation,
                onRequestPermission = {
                    backgroundLocationPermissionState?.launchPermissionRequest()
                }
            )
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        // Battery optimization section
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = "Settings",
                        modifier = Modifier.size(24.dp)
                    )
                    
                    Spacer(modifier = Modifier.width(8.dp))
                    
                    Text(
                        text = "Battery Optimization",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    text = "For best performance, disable battery optimization for Located. This ensures location tracking works reliably in the background.",
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Spacer(modifier = Modifier.height(12.dp))
                
                OutlinedButton(
                    onClick = { viewModel.requestBatteryOptimizationExemption() },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Disable Battery Optimization")
                }
            }
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        // Error message
        uiState.errorMessage?.let { error ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer
                )
            ) {
                Text(
                    text = error,
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer,
                    textAlign = TextAlign.Center
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
        }
        
        // Continue button (only show when all permissions are granted)
        if (uiState.permissionStatus.hasAllPermissions()) {
            Button(
                onClick = {
                    viewModel.startLocationTracking()
                    onPermissionsGranted()
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Start Location Tracking")
            }
        }
    }
}

@Composable
fun PermissionStatusCard(
    title: String,
    description: String,
    isGranted: Boolean,
    onRequestPermission: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (isGranted) {
                MaterialTheme.colorScheme.primaryContainer
            } else {
                MaterialTheme.colorScheme.surfaceVariant
            }
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(
                    modifier = Modifier.weight(1f)
                ) {
                    Text(
                        text = title,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                    
                    Text(
                        text = description,
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                
                if (isGranted) {
                    Text(
                        text = "Granted",
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Medium
                    )
                } else {
                    Button(
                        onClick = onRequestPermission,
                        size = ButtonDefaults.SmallButtonSize
                    ) {
                        Text("Grant")
                    }
                }
            }
        }
    }
}
