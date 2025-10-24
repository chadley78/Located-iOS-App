package com.located.app.presentation.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.located.app.presentation.auth.AuthViewModel
import com.located.app.presentation.location.LocationPermissionScreen

@Composable
fun SettingsScreen(viewModel: AuthViewModel = hiltViewModel()) {
    val authUiState = viewModel.uiState.collectAsStateWithLifecycle().value
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.Start
    ) {
        Text(
            text = "Settings",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )

        Text(text = "Debug", fontSize = 16.sp, fontWeight = FontWeight.Medium)
        Spacer(Modifier.height(8.dp))
        Text(
            text = "User ID: ${authUiState.currentUser?.id ?: "-"}",
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = "Family ID: ${authUiState.currentUser?.familyId ?: "-"}",
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Button(onClick = { viewModel.signOut() }, modifier = Modifier.padding(top = 24.dp)) {
            Text("Sign Out")
        }

        // Embed location permissions UI for Phase 3 testing
        Spacer(Modifier.height(24.dp))
        LocationPermissionScreen(onContinue = {})
    }
}


