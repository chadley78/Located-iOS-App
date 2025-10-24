package com.located.app.presentation.navigation

import androidx.compose.runtime.*
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.located.app.presentation.auth.*

@Composable
fun AuthNavigation(
    onNavigateToHome: () -> Unit
) {
    var currentScreen by remember { mutableStateOf(AuthScreen.ROLE_SELECTION) }
    val viewModel: AuthViewModel = hiltViewModel()
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    
    // Handle navigation based on auth state
    LaunchedEffect(uiState.isAuthenticated) {
        if (uiState.isAuthenticated) {
            onNavigateToHome()
        }
    }
    
    when (currentScreen) {
        AuthScreen.ROLE_SELECTION -> {
            RoleSelectionScreen(
                viewModel = viewModel,
                onNavigateToParent = { currentScreen = AuthScreen.PARENT_AUTH },
                onNavigateToChild = { currentScreen = AuthScreen.CHILD_INVITATION }
            )
        }
        AuthScreen.PARENT_AUTH -> {
            ParentAuthScreen(
                viewModel = viewModel,
                onNavigateBack = { currentScreen = AuthScreen.ROLE_SELECTION }
            )
        }
        AuthScreen.CHILD_INVITATION -> {
            ChildInvitationScreen(
                viewModel = viewModel,
                onNavigateBack = { currentScreen = AuthScreen.ROLE_SELECTION }
            )
        }
    }
    
    // Handle welcome flow
    if (uiState.shouldShowWelcome) {
        ChildWelcomeScreen(viewModel = viewModel)
    }
}

enum class AuthScreen {
    ROLE_SELECTION,
    PARENT_AUTH,
    CHILD_INVITATION
}
