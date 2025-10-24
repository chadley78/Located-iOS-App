package com.located.app.util

import android.content.Intent
import android.net.Uri
import com.located.app.presentation.auth.AuthViewModel

class DeepLinkHandler {
    
    companion object {
        const val DEEP_LINK_SCHEME = "located"
        const val DEEP_LINK_HOST = "invite"
        
        fun handleDeepLink(intent: Intent): String? {
            val data: Uri? = intent.data
            if (data != null && data.scheme == DEEP_LINK_SCHEME && data.host == DEEP_LINK_HOST) {
                val pathSegments = data.pathSegments
                if (pathSegments.isNotEmpty()) {
                    val invitationCode = pathSegments[0]
                    println("🔗 Deep link detected: invitation code = $invitationCode")
                    return invitationCode
                }
            }
            return null
        }
        
        fun createInvitationDeepLink(invitationCode: String): String {
            return "$DEEP_LINK_SCHEME://$DEEP_LINK_HOST/$invitationCode"
        }
        
        fun isValidInvitationCode(code: String): Boolean {
            // Invitation codes are typically 6 characters, alphanumeric, uppercase
            return code.matches(Regex("[A-Z0-9]{6}"))
        }
    }
}
