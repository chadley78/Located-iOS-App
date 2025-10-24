package com.located.app.presentation.location

import android.Manifest
import android.os.Build
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts

@Composable
fun LocationPermissionScreen(
    viewModel: LocationViewModel = hiltViewModel(),
    onContinue: () -> Unit = {}
) {
    LaunchedEffect(Unit) { viewModel.refreshPermissions() }
    val ui by viewModel.uiState.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Enable Location", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(12.dp))
        Text(
            "Located uses your location to keep your family connected and safe.",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(Modifier.height(24.dp))

        PermissionRow("Fine location", ui.hasFine)
        PermissionRow("Coarse location", ui.hasCoarse)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            PermissionRow("Background location", ui.hasBackground)
        }

        // Launchers for permission requests
        val basicPermsLauncher = rememberLauncherForActivityResult(
            contract = ActivityResultContracts.RequestMultiplePermissions()
        ) {
            viewModel.refreshPermissions()
        }
        val backgroundPermLauncher = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            rememberLauncherForActivityResult(
                contract = ActivityResultContracts.RequestPermission()
            ) {
                viewModel.refreshPermissions()
            }
        } else null

        Spacer(Modifier.height(12.dp))

        if (!(ui.hasFine && ui.hasCoarse)) {
            Button(
                onClick = {
                    basicPermsLauncher.launch(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        )
                    )
                },
                modifier = Modifier.fillMaxWidth()
            ) { Text("Grant Basic Location Permissions") }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !ui.hasBackground) {
            Spacer(Modifier.height(8.dp))
            OutlinedButton(
                onClick = {
                    backgroundPermLauncher?.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
                },
                modifier = Modifier.fillMaxWidth()
            ) { Text("Grant Background Location") }
        }

        Spacer(Modifier.height(24.dp))

        Button(
            onClick = {
                viewModel.startLocationTracking()
                onContinue()
            },
            enabled = ui.hasFine && ui.hasCoarse && (ui.hasBackground || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q),
            modifier = Modifier.fillMaxWidth()
        ) { Text("Start Location Sharing") }

        Spacer(Modifier.height(12.dp))
        OutlinedButton(onClick = { viewModel.openBatteryOptimizationSettings() }, modifier = Modifier.fillMaxWidth()) {
            Text("Battery Optimization Settings")
        }
    }
}

@Composable
private fun PermissionRow(label: String, granted: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label)
        val color = if (granted) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
        Text(if (granted) "Granted" else "Missing", color = color, fontWeight = FontWeight.Medium)
    }
}
