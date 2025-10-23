package com.located.app.data.model

import java.util.Date

data class FamilyInvitation(
    val id: String, // This is the invite code
    val familyId: String,
    val createdBy: String, // Parent user ID
    val childName: String,
    val role: FamilyRole, // Role for this invitation (parent or child)
    val createdAt: Date,
    val expiresAt: Date,
    val usedBy: String? = null, // User ID who used the invitation
    val usedAt: Date? = null // When the invitation was used
) {
    val isExpired: Boolean
        get() = Date() > expiresAt
    
    val isUsed: Boolean
        get() = usedBy != null
    
    val isValid: Boolean
        get() = !isExpired && !isUsed
}
