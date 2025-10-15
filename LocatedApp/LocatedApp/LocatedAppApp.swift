import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import GoogleSignIn

@main
struct LocatedAppApp: App {
    // Register AppDelegate for handling APNs token
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var familyService = FamilyService()
    @StateObject private var notificationService = NotificationService()
    @State private var deepLinkInvitationCode: String?
    
    // Initialize Firebase and background services when the app launches
    init() {
        // Configure Firebase immediately in the initializer
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
        
        // Configure Firebase Messaging
        Messaging.messaging().delegate = FirebaseMessagingDelegate.shared
        print("✅ Firebase Messaging configured")
        
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
        }
    }
    
    private func handleDeepLink(url: URL) {
        print("🔗 Received deep link: \(url)")
        
        // Handle Google Sign-In callback
        if GIDSignIn.sharedInstance.handle(url) {
            print("🔗 Handled by Google Sign-In")
            return
        }
        
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