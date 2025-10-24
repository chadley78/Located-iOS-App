package com.located.app.data.repository

import com.google.firebase.firestore.FirebaseFirestore
import com.located.app.data.model.Family
import com.located.app.data.model.FamilyMember
import com.located.app.data.model.FamilyRole
import com.located.app.data.model.InvitationStatus
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FamilyRepository @Inject constructor(
    private val firestore: FirebaseFirestore
) {
    
    suspend fun getFamilyById(familyId: String): Family? {
        return try {
            val document = firestore.collection("families").document(familyId).get().await()
            if (document.exists()) {
                document.toObject(Family::class.java)?.copy(id = familyId)
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }
    
    suspend fun createFamily(name: String, createdBy: String): Result<Family> {
        return try {
            val familyId = firestore.collection("families").document().id

            // Try to read the creator's name from the user profile for member entry
            val creatorDoc = firestore.collection("users").document(createdBy).get().await()
            val creatorName = (creatorDoc.data?.get("name") as? String) ?: ""
            val family = Family(
                id = familyId,
                name = name,
                createdBy = createdBy,
                createdAt = java.util.Date(),
                members = mapOf(
                    createdBy to FamilyMember(
                        role = FamilyRole.PARENT,
                        name = creatorName,
                        joinedAt = java.util.Date(),
                        status = InvitationStatus.ACCEPTED
                    )
                )
            )
            
            val familyData = mapOf(
                "id" to family.id,
                "name" to family.name,
                "createdBy" to family.createdBy,
                "createdAt" to family.createdAt,
                "members" to family.members.mapValues { (_, member) ->
                    mapOf(
                        "role" to member.role.name.lowercase(),
                        "name" to member.name,
                        "joinedAt" to member.joinedAt,
                        "status" to member.status.name.lowercase()
                    )
                }
            )
            
            firestore.collection("families").document(familyId).set(familyData).await()
            // Link the user to the newly created family
            firestore.collection("users").document(createdBy)
                .update("familyId", familyId)
                .await()
            Result.success(family)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun updateFamilyMember(familyId: String, userId: String, member: FamilyMember): Result<Unit> {
        return try {
            val memberData = mapOf(
                "role" to member.role.name.lowercase(),
                "name" to member.name,
                "joinedAt" to member.joinedAt,
                "status" to member.status.name.lowercase(),
                "imageURL" to member.imageURL,
                "imageBase64" to member.imageBase64,
                "hasImage" to member.hasImage
            )
            
            firestore.collection("families").document(familyId)
                .update("members.$userId", memberData).await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
