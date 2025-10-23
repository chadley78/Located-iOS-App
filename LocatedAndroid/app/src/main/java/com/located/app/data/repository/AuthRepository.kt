package com.located.app.data.repository

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.located.app.data.model.User
import com.located.app.data.model.UserType
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val auth: FirebaseAuth,
    private val firestore: FirebaseFirestore
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
    
    suspend fun resetPassword(email: String): Result<Unit> {
        return try {
            auth.sendPasswordResetEmail(email).await()
            Result.success(Unit)
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
            document.toObject(User::class.java)?.copy(id = userId) ?: createDefaultUser(userId)
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
        
        val defaultUser = User(
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
            "userType" to user.userType.name,
            "familyId" to user.familyId,
            "createdAt" to user.createdAt,
            "lastActive" to user.lastActive,
            "isActive" to user.isActive,
            "fcmTokens" to user.fcmTokens
        )
        
        firestore.collection("users").document(user.id ?: "").set(userData).await()
    }
}
