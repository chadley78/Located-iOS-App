package com.located.app.presentation.home

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.located.app.presentation.auth.AuthViewModel
import com.located.app.presentation.family.FamilyViewModel

@Composable
fun HomeScreen(
    authViewModel: AuthViewModel = hiltViewModel(),
    familyViewModel: FamilyViewModel = hiltViewModel()
) {
    val authUiState by authViewModel.uiState.collectAsStateWithLifecycle()
    val familyUiState by familyViewModel.uiState.collectAsStateWithLifecycle()
    
    // Initialize family listener when user is authenticated
    LaunchedEffect(authUiState.isAuthenticated, authUiState.currentUser?.id) {
        if (authUiState.isAuthenticated && authUiState.currentUser?.id != null) {
            familyViewModel.handleAuthStateChange(
                isAuthenticated = true,
                userId = authUiState.currentUser?.id
            )
        } else {
            familyViewModel.handleAuthStateChange(
                isAuthenticated = false,
                userId = null
            )
        }
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Welcome to Located!",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        authUiState.currentUser?.let { user ->
            Text(
                text = "Hello, ${user.name}!",
                fontSize = 20.sp,
                fontWeight = FontWeight.Medium
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = "User Type: ${user.userType.name}",
                fontSize = 16.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            
            if (user.familyId != null) {
                Text(
                    text = "Family ID: ${user.familyId}",
                    fontSize = 16.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "Next Steps",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    text = "• Create or join a family",
                    fontSize = 14.sp
                )
                Text(
                    text = "• Set up location tracking",
                    fontSize = 14.sp
                )
                Text(
                    text = "• Create geofences",
                    fontSize = 14.sp
                )
                Text(
                    text = "• Start monitoring",
                    fontSize = 14.sp
                )
            }
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        // Family Management Section
        if (familyUiState.currentFamily != null) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Text(
                        text = "Family: ${familyUiState.currentFamily?.name}",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                    
                    Text(
                        text = "${familyUiState.familyMembers.size} members",
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
        }
        
        Button(
            onClick = { authViewModel.signOut() },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Sign Out")
        }
    }
}
