import SwiftUI
import FirebaseCore

@main
struct LocatedAppApp: App {
    @StateObject private var familyService = FamilyService()
    @StateObject private var notificationService = NotificationService()
    @State private var deepLinkInvitationCode: String?
    
    // Initialize Firebase and background services when the app launches
    init() {
        // Configure Firebase immediately in the initializer
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
        
        // Initialize background location manager
        _ = BackgroundLocationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(invitationCode: deepLinkInvitationCode)
                .environmentObject(familyService)
                .environmentObject(notificationService)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .onAppear {
                    // Register for notifications when app appears
                    Task {
                        await notificationService.registerFCMToken()
                    }
                }
        }
    }
    
    private func handleDeepLink(url: URL) {
        print("🔗 Received deep link: \(url)")
        
        // Parse URL scheme: located://invite/ABC123
        if url.scheme == "located" && url.host == "invite" {
            let pathComponents = url.pathComponents
            if pathComponents.count >= 2 {
                let invitationCode = pathComponents[1]
                print("🔗 Extracted invitation code: \(invitationCode)")
                deepLinkInvitationCode = invitationCode
            }
        }
        
        // Parse universal link: https://located.app/invite/ABC123
        if url.host == "located.app" && url.path.hasPrefix("/invite/") {
            let pathComponents = url.pathComponents
            if pathComponents.count >= 3 {
                let invitationCode = pathComponents[2]
                print("🔗 Extracted invitation code from universal link: \(invitationCode)")
                deepLinkInvitationCode = invitationCode
            }
        }
    }
}