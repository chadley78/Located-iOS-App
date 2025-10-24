package com.located.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.located.app.presentation.auth.AuthViewModel
import com.located.app.presentation.navigation.MainTabScreen
import com.located.app.presentation.navigation.AuthNavigation
import com.located.app.presentation.theme.LocatedTheme
import com.located.app.util.DeepLinkHandler
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    
    private val authViewModel: AuthViewModel by viewModels()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            LocatedTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    var showHome by remember { mutableStateOf(false) }
                    var invitationCode by remember { mutableStateOf<String?>(null) }
                    
                    // Handle deep link from intent
                    LaunchedEffect(Unit) {
                        handleDeepLink(intent)
                        invitationCode = extractInvitationCode(intent)
                    }
                    
                    if (showHome) {
                        MainTabScreen()
                    } else {
                        AuthNavigation(
                            onNavigateToHome = { showHome = true },
                            invitationCode = invitationCode
                        )
                    }
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        intent?.let { handleDeepLink(it) }
    }
    
    private fun handleDeepLink(intent: Intent) {
        val invitationCode = DeepLinkHandler.handleDeepLink(intent)
        if (invitationCode != null) {
            println("🔗 Handling deep link with invitation code: $invitationCode")
            // The invitation code will be passed to the AuthNavigation
        }
    }
    
    private fun extractInvitationCode(intent: Intent): String? {
        return DeepLinkHandler.handleDeepLink(intent)
    }
}
