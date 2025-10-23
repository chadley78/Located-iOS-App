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
    val fcmTokens: List<String> = emptyList()
)

enum class UserType {
    PARENT,
    CHILD
}
