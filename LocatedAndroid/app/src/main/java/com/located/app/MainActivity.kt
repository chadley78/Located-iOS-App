package com.located.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.located.app.presentation.auth.WelcomeScreen
import com.located.app.presentation.home.HomeScreen
import com.located.app.presentation.navigation.AuthNavigation
import com.located.app.presentation.theme.LocatedTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            LocatedTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    var showHome by remember { mutableStateOf(false) }
                    
                    if (showHome) {
                        HomeScreen()
                    } else {
                        AuthNavigation(
                            onNavigateToHome = { showHome = true }
                        )
                    }
                }
            }
        }
    }
}
