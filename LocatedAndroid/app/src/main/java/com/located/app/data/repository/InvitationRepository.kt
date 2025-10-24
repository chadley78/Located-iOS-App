package com.located.app.data.repository

import com.google.firebase.functions.FirebaseFunctions
import com.located.app.data.model.FamilyInvitation
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class InvitationRepository @Inject constructor(
    private val functions: FirebaseFunctions
) {
    
    suspend fun acceptInvitation(inviteCode: String): Result<Map<String, Any>> {
        return try {
            val data = hashMapOf(
                "inviteCode" to inviteCode.trim().uppercase()
            )
            
            val result = functions.getHttpsCallable("acceptInvitation").call(data).await()
            val dataResult = result.data as? Map<String, Any> ?: emptyMap()
            
            Result.success(dataResult)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun createInvitation(familyId: String, childName: String): Result<FamilyInvitation> {
        return try {
            val data = hashMapOf(
                "familyId" to familyId,
                "childName" to childName
            )
            
            val result = functions.getHttpsCallable("createInvitation").call(data).await()
            val dataResult = result.data as? Map<String, Any> ?: emptyMap()
            
            val invitation = FamilyInvitation(
                id = dataResult["inviteCode"] as? String ?: "",
                familyId = familyId,
                createdBy = "", // Will be set by the Cloud Function
                childName = childName,
                role = com.located.app.data.model.FamilyRole.CHILD,
                createdAt = java.util.Date(),
                expiresAt = java.util.Date(System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000L) // 7 days
            )
            
            Result.success(invitation)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun validateInvitationCode(inviteCode: String): Result<Map<String, Any>> {
        return try {
            val data = hashMapOf(
                "inviteCode" to inviteCode.trim().uppercase()
            )
            
            val result = functions.getHttpsCallable("validateInvitation").call(data).await()
            val dataResult = result.data as? Map<String, Any> ?: emptyMap()
            
            Result.success(dataResult)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
