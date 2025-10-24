package com.located.app.presentation.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.hilt.navigation.compose.hiltViewModel
import com.located.app.presentation.auth.AuthViewModel
import com.located.app.presentation.family.FamilyManagementScreen
import com.located.app.presentation.home.ChildHomeScreen
import com.located.app.presentation.home.ParentHomeScreen
import com.located.app.presentation.settings.SettingsScreen

@Composable
fun MainTabScreen(
    modifier: Modifier = Modifier,
    authViewModel: AuthViewModel = hiltViewModel()
) {
    val navController = rememberNavController()

    Scaffold(
        bottomBar = {
            NavigationBar {
                val navBackStackEntry by navController.currentBackStackEntryAsState()
                val currentDestination = navBackStackEntry?.destination

                listOf(
                    MainTab.Home,
                    MainTab.Family,
                    MainTab.Settings
                ).forEach { tab ->
                    NavigationBarItem(
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) },
                        selected = currentDestination?.hierarchy?.any { it.route == tab.route } == true,
                        onClick = {
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = MainTab.Home.route,
            modifier = modifier.then(Modifier).padding(innerPadding)
        ) {
            composable(MainTab.Home.route) {
                // Decide Parent vs Child home from auth state
                val user = authViewModel.uiState.value.currentUser
                if (user?.userType?.name?.lowercase() == "parent") {
                    ParentHomeScreen()
                } else {
                    ChildHomeScreen()
                }
            }
            composable(MainTab.Family.route) {
                FamilyManagementScreen()
            }
            composable(MainTab.Settings.route) {
                SettingsScreen()
            }
        }
    }
}

private enum class MainTab(val route: String, val label: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Home("tab_home", "Home", Icons.Default.Home),
    Family("tab_family", "My Family", Icons.Default.Person),
    Settings("tab_settings", "Settings", Icons.Default.Settings)
}


