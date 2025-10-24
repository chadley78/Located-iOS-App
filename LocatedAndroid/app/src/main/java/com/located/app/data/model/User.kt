package com.located.app.data.model

import java.util.Date

data class User(
    val id: String? = null,
    val name: String,
    val email: String,
    val userType: UserType,
    val familyId: String? = null,
    val createdAt: Date = Date(),
    val lastActive: Date = Date(),
    val isActive: Boolean = true,
    val fcmTokens: List<String> = emptyList(),
    val isExistingChild: Boolean? = null // For tracking existing children during invitation flow
) {
    companion object {
        fun create(
            id: String? = null,
            name: String,
            email: String,
            userType: UserType,
            familyId: String? = null
        ): User {
            return User(
                id = id,
                name = name,
                email = email,
                userType = userType,
                familyId = familyId,
                createdAt = Date(),
                lastActive = Date(),
                isActive = true,
                fcmTokens = emptyList()
            )
        }
    }
}

enum class UserType(val value: String) {
    PARENT("parent"),
    CHILD("child")
}
