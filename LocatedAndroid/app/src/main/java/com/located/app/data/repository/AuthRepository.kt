package com.located.app.data.repository

import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.FirebaseFirestore
import com.located.app.data.model.User
import com.located.app.data.model.UserType
import java.util.UUID
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val auth: FirebaseAuth,
    private val firestore: FirebaseFirestore,
    private val googleSignInClient: GoogleSignInClient,
    private val invitationRepository: InvitationRepository
) {
    
    suspend fun signUp(
        email: String,
        password: String,
        name: String,
        userType: UserType
    ): Result<User> {
        return try {
            val authResult = auth.createUserWithEmailAndPassword(email, password).await()
            val newUser = User(
                id = authResult.user?.uid,
                name = name,
                email = email,
                userType = userType
            )
            
            // Save user profile to Firestore
            saveUserProfile(newUser)
            Result.success(newUser)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun signIn(email: String, password: String): Result<User> {
        return try {
            val authResult = auth.signInWithEmailAndPassword(email, password).await()
            val user = fetchUserProfile(authResult.user?.uid ?: "")
            Result.success(user)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun signOut(): Result<Unit> {
        return try {
            auth.signOut()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun signInWithGoogle(idToken: String): Result<User> {
        return try {
            val credential = GoogleAuthProvider.getCredential(idToken, null)
            val authResult = auth.signInWithCredential(credential).await()
            
            val user = if (authResult.additionalUserInfo?.isNewUser == true) {
                // New user - create profile
                val newUser = User(
                    id = authResult.user?.uid,
                    name = authResult.user?.displayName ?: "User",
                    email = authResult.user?.email ?: "",
                    userType = UserType.PARENT // Default to parent for Google Sign-In
                )
                saveUserProfile(newUser)
                newUser
            } else {
                // Existing user - fetch profile
                fetchUserProfile(authResult.user?.uid ?: "")
            }
            
            Result.success(user)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun resetPassword(email: String): Result<Unit> {
        return try {
            auth.sendPasswordResetEmail(email).await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    // Child invitation flow - matches iOS implementation
    suspend fun signUpChildWithInvitation(inviteCode: String): Result<User> {
        return try {
            // First validate the invitation
            val validationResult = invitationRepository.validateInvitationCode(inviteCode)
            if (validationResult.isFailure) {
                return Result.failure(validationResult.exceptionOrNull() ?: Exception("Invalid invitation code"))
            }
            
            // Generate temporary email and password for the child (matches iOS logic)
            val tempEmail = "child_${UUID.randomUUID()}@temp.located.app"
            val tempPassword = "temp_${UUID.randomUUID().toString().take(8)}"
            
            // Create user account with temporary email
            val authResult = auth.createUserWithEmailAndPassword(tempEmail, tempPassword).await()
            val userId = authResult.user?.uid ?: throw Exception("Failed to create user account")
            
            // Create user profile with temporary name
            val newUser = User.create(
                id = userId,
                name = "Child", // Temporary name, will be updated from invitation
                email = tempEmail,
                userType = UserType.CHILD
            )
            
            // Save user profile to Firestore
            saveUserProfile(newUser)
            
            // Accept the invitation (user is now authenticated)
            val invitationResult = invitationRepository.acceptInvitation(inviteCode)
            if (invitationResult.isFailure) {
                // Clean up the created user if invitation acceptance fails
                authResult.user?.delete()
                return Result.failure(invitationResult.exceptionOrNull() ?: Exception("Failed to accept invitation"))
            }
            
            // Get child name from invitation result
            val resultData = invitationResult.getOrThrow()
            val childName = resultData["childName"] as? String ?: "Child"
            
            // Update the user's display name with the correct name from invitation
            val profileUpdates = com.google.firebase.auth.UserProfileChangeRequest.Builder()
                .setDisplayName(childName)
                .build()
            authResult.user?.updateProfile(profileUpdates)?.await()
            
            // Update the user profile with the correct name
            val updatedUser = newUser.copy(name = childName)
            saveUserProfile(updatedUser)
            
            // Add a short delay to ensure Firestore write is visible (matches iOS logic)
            kotlinx.coroutines.delay(2000)
            
            // Check if this was for an existing child
            val isExistingChild = resultData["isExistingChild"] as? Boolean ?: false
            
            Result.success(updatedUser.copy(isExistingChild = isExistingChild))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun getCurrentUser(): User? {
        val firebaseUser = auth.currentUser ?: return null
        return try {
            fetchUserProfile(firebaseUser.uid)
        } catch (e: Exception) {
            null
        }
    }
    
    private suspend fun fetchUserProfile(userId: String): User {
        val document = firestore.collection("users").document(userId).get().await()
        return if (document.exists()) {
            val data = document.data
            if (data != null) {
                val userTypeString = data["userType"] as? String ?: "parent"
                val userType = when (userTypeString.lowercase()) {
                    "child" -> UserType.CHILD
                    else -> UserType.PARENT
                }
                
                User(
                    id = userId,
                    name = data["name"] as? String ?: "User",
                    email = data["email"] as? String ?: "",
                    userType = userType,
                    familyId = data["familyId"] as? String,
                    createdAt = (data["createdAt"] as? com.google.firebase.Timestamp)?.toDate() ?: java.util.Date(),
                    lastActive = (data["lastActive"] as? com.google.firebase.Timestamp)?.toDate() ?: java.util.Date(),
                    isActive = data["isActive"] as? Boolean ?: true,
                    fcmTokens = (data["fcmTokens"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
                )
            } else {
                createDefaultUser(userId)
            }
        } else {
            createDefaultUser(userId)
        }
    }
    
    private suspend fun createDefaultUser(userId: String): User {
        val firebaseUser = auth.currentUser ?: throw Exception("No authenticated user")
        
        // Determine user type from email or other context
        val userType = if (firebaseUser.email?.contains("@temp.located.app") == true) {
            UserType.CHILD
        } else {
            UserType.PARENT
        }
        
        val defaultUser = User.create(
            id = userId,
            name = firebaseUser.displayName ?: "User",
            email = firebaseUser.email ?: "",
            userType = userType
        )
        
        saveUserProfile(defaultUser)
        return defaultUser
    }
    
    private suspend fun saveUserProfile(user: User) {
        val userData = mapOf(
            "name" to user.name,
            "email" to user.email,
            "userType" to user.userType.value, // Use the string value
            "familyId" to user.familyId,
            "createdAt" to user.createdAt,
            "lastActive" to user.lastActive,
            "isActive" to user.isActive,
            "fcmTokens" to user.fcmTokens
        )
        
        firestore.collection("users").document(user.id ?: "").set(userData).await()
    }
}
