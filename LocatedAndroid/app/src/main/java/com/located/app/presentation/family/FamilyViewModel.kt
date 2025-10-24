package com.located.app.presentation.family

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.located.app.data.model.Family
import com.located.app.data.model.FamilyMember
import com.located.app.data.model.FamilyRole
import com.located.app.data.repository.FamilyRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FamilyViewModel @Inject constructor(
    private val auth: FirebaseAuth,
    private val firestore: FirebaseFirestore,
    private val familyRepository: FamilyRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(FamilyUiState())
    val uiState: StateFlow<FamilyUiState> = _uiState.asStateFlow()
    
    private var userListener: ListenerRegistration? = null
    private var familyListener: ListenerRegistration? = null
    
    init {
        println("🔍 FamilyViewModel initialized")
    }
    
    fun handleAuthStateChange(isAuthenticated: Boolean, userId: String?) {
        if (isAuthenticated && userId != null) {
            println("🔍 User authenticated, starting family listener for: $userId")
            startFamilyListener(userId)
        } else {
            println("🔍 User not authenticated, stopping family listener")
            stopFamilyListeners()
            _uiState.value = _uiState.value.copy(
                currentFamily = null,
                familyMembers = emptyMap()
            )
        }
    }
    
    private fun startFamilyListener(userId: String) {
        // Stop existing listeners
        stopFamilyListeners()
        
        println("🔍 Starting to listen for family changes for user: $userId")
        
        // First get the user's familyId
        userListener = firestore.collection("users").document(userId)
            .addSnapshotListener { documentSnapshot, error ->
                if (error != null) {
                    println("❌ Error listening to user document: $error")
                    return@addSnapshotListener
                }
                
                val data = documentSnapshot?.data
                val familyId = data?.get("familyId") as? String
                
                if (familyId == null) {
                    println("ℹ️ User has no familyId")
                    familyListener?.remove()
                    _uiState.value = _uiState.value.copy(
                        currentFamily = null,
                        familyMembers = emptyMap()
                    )
                    return@addSnapshotListener
                }
                
                println("🔍 User has familyId: $familyId")
                
                // Stop old family listener
                familyListener?.remove()
                
                // Listen to family document
                familyListener = firestore.collection("families").document(familyId)
                    .addSnapshotListener { familySnapshot, familyError ->
                        if (familyError != null) {
                            println("❌ Error listening to family document: $familyError")
                            return@addSnapshotListener
                        }
                        
                        val familyData = familySnapshot?.data
                        if (familyData == null) {
                            println("ℹ️ Family document not found")
                            return@addSnapshotListener
                        }
                        
                        try {
                            val family = parseFamilyFromData(familyId, familyData)
                            println("✅ Successfully loaded family: ${family.name} with ${family.members.size} members")
                            
                            // Debug: Print all members and their status
                            for ((id, member) in family.members) {
                                println("🔍 Family member: ${member.name} (role: ${member.role}, status: ${member.status})")
                            }
                            
                            _uiState.value = _uiState.value.copy(
                                currentFamily = family,
                                familyMembers = family.members
                            )
                        } catch (e: Exception) {
                            println("❌ Error parsing family: $e")
                        }
                    }
            }
    }
    
    private fun parseFamilyFromData(familyId: String, data: Map<String, Any>): Family {
        val name = data["name"] as? String ?: "Unknown Family"
        val createdBy = data["createdBy"] as? String ?: ""
        val createdAt = (data["createdAt"] as? com.google.firebase.Timestamp)?.toDate() ?: java.util.Date()
        
        // Parse members
        val membersData = data["members"] as? Map<String, Any> ?: emptyMap()
        val members = membersData.mapValues { (_, memberData) ->
            val memberMap = memberData as? Map<String, Any> ?: emptyMap()
            val roleString = memberMap["role"] as? String ?: "parent"
            val role = when (roleString.lowercase()) {
                "child" -> FamilyRole.CHILD
                else -> FamilyRole.PARENT
            }
            val statusString = memberMap["status"] as? String ?: "accepted"
            val status = when (statusString.lowercase()) {
                "pending" -> com.located.app.data.model.InvitationStatus.PENDING
                "declined" -> com.located.app.data.model.InvitationStatus.DECLINED
                else -> com.located.app.data.model.InvitationStatus.ACCEPTED
            }
            
            FamilyMember(
                role = role,
                name = memberMap["name"] as? String ?: "Unknown",
                joinedAt = (memberMap["joinedAt"] as? com.google.firebase.Timestamp)?.toDate() ?: java.util.Date(),
                status = status,
                imageURL = memberMap["imageURL"] as? String,
                imageBase64 = memberMap["imageBase64"] as? String,
                hasImage = memberMap["hasImage"] as? Boolean
            )
        }
        
        return Family(
            id = familyId,
            name = name,
            createdBy = createdBy,
            createdAt = createdAt,
            members = members
        )
    }
    
    private fun stopFamilyListeners() {
        userListener?.remove()
        familyListener?.remove()
        userListener = null
        familyListener = null
    }
    
    fun getFamilyMembers(): List<Pair<String, FamilyMember>> {
        return _uiState.value.familyMembers.toList()
    }
    
    fun getChildren(): List<Pair<String, FamilyMember>> {
        return _uiState.value.familyMembers.filter { it.value.role == FamilyRole.CHILD }
    }
    
    fun createFamily(name: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            
            val userId = auth.currentUser?.uid ?: return@launch
            familyRepository.createFamily(name, userId)
                .onSuccess { family ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        currentFamily = family
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
    
    override fun onCleared() {
        super.onCleared()
        stopFamilyListeners()
    }
}

data class FamilyUiState(
    val currentFamily: Family? = null,
    val familyMembers: Map<String, FamilyMember> = emptyMap(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)
