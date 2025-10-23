package com.located.app.data.model

import java.util.Date

data class Family(
    val id: String,
    val name: String,
    val createdBy: String, // Parent user ID who created the family
    val createdAt: Date,
    val members: Map<String, FamilyMember>, // Map of userId -> FamilyMember
    val subscriptionStatus: SubscriptionStatus? = null,
    val trialEndsAt: Date? = null,
    val subscriptionExpiresAt: Date? = null
)

data class FamilyMember(
    val role: FamilyRole,
    val name: String,
    val joinedAt: Date,
    val imageURL: String? = null,
    val imageBase64: String? = null,
    val hasImage: Boolean? = null,
    val status: InvitationStatus = InvitationStatus.ACCEPTED
)

enum class FamilyRole {
    PARENT,
    CHILD
}

enum class InvitationStatus {
    PENDING,
    ACCEPTED,
    DECLINED
}

enum class SubscriptionStatus {
    TRIAL,
    ACTIVE,
    EXPIRED,
    CANCELED
}
