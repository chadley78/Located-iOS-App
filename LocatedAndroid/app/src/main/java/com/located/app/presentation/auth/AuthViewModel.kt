package com.located.app.presentation.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.located.app.data.model.User
import com.located.app.data.model.UserType
import com.located.app.data.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val auth: FirebaseAuth
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()
    
    init {
        // Listen for auth state changes
        auth.addAuthStateListener { firebaseUser ->
            viewModelScope.launch {
                println("DEBUG: Auth state changed - user: ${firebaseUser?.uid}")
                println("DEBUG: firebaseUser is null: ${firebaseUser == null}")
                println("DEBUG: firebaseUser.uid is null: ${firebaseUser?.uid == null}")
                if (firebaseUser?.uid != null) {
                    println("DEBUG: Going to authenticated branch")
                    val user = authRepository.getCurrentUser()
                    println("DEBUG: User authenticated: ${user?.name}")
                    _uiState.value = _uiState.value.copy(
                        isAuthenticated = true,
                        currentUser = user,
                        isLoading = false
                    )
                } else {
                    println("DEBUG: Going to signed out branch")
                    println("DEBUG: User signed out - setting isAuthenticated = false")
                    _uiState.value = _uiState.value.copy(
                        isAuthenticated = false,
                        currentUser = null,
                        isLoading = false
                    )
                }
            }
        }
    }
    
    fun signUp(email: String, password: String, name: String, userType: UserType) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            
            authRepository.signUp(email, password, name, userType)
                .onSuccess { user ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isAuthenticated = true,
                        currentUser = user
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message
                    )
                }
        }
    }
    
    fun signIn(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            
            authRepository.signIn(email, password)
                .onSuccess { user ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isAuthenticated = true,
                        currentUser = user
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message
                    )
                }
        }
    }
    
    fun signOut() {
        viewModelScope.launch {
            println("DEBUG: Starting sign out...")
            authRepository.signOut()
                .onSuccess {
                    println("DEBUG: Sign out successful")
                    _uiState.value = _uiState.value.copy(
                        isAuthenticated = false,
                        currentUser = null,
                        errorMessage = null
                    )
                }
                .onFailure { error ->
                    println("DEBUG: Sign out failed: ${error.message}")
                    _uiState.value = _uiState.value.copy(
                        errorMessage = error.message
                    )
                }
        }
    }
    
    fun signInWithGoogle(idToken: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            
            authRepository.signInWithGoogle(idToken)
                .onSuccess { user ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isAuthenticated = true,
                        currentUser = user
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message
                    )
                }
        }
    }
    
    fun resetPassword(email: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            
            authRepository.resetPassword(email)
                .onSuccess {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = "Password reset email sent to $email"
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message
                    )
                }
        }
    }
    
    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}

data class AuthUiState(
    val isAuthenticated: Boolean = false,
    val currentUser: User? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)
