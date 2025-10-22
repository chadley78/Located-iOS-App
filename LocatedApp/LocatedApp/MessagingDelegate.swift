import Foundation
import FirebaseMessaging
import UserNotifications
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firebase Messaging Delegate
class FirebaseMessagingDelegate: NSObject, MessagingDelegate {
    static let shared = FirebaseMessagingDelegate()
    
    private override init() {
        super.init()
    }
    
    // MARK: - MessagingDelegate Methods
    
    /// Called when FCM token is refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔄 FCM Registration Token: \(fcmToken ?? "nil")")
        
        // Store the token for later use
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcm_token")
            print("✅ FCM token stored locally: \(token)")
            
            // Automatically save to Firestore if user is authenticated
            Task {
                await saveFCMTokenToFirestore(token)
            }
        }
    }
    
    /// Save FCM token to Firestore
    private func saveFCMTokenToFirestore(_ fcmToken: String) async {
        guard let currentUser = Auth.auth().currentUser else {
            print("⚠️ Cannot save FCM token - user not authenticated")
            return
        }
        
        do {
            let db = Firestore.firestore()
            try await db.collection("users").document(currentUser.uid).updateData([
                "fcmTokens": FieldValue.arrayUnion([fcmToken])
            ])
            print("✅ FCM token automatically saved to Firestore: \(fcmToken)")
        } catch {
            print("❌ Failed to save FCM token to Firestore: \(error.localizedDescription)")
        }
    }
    
    /// Called when APNs token is received
    func messaging(_ messaging: Messaging, didReceive apnsToken: Data) {
        print("📱 APNs token received: \(apnsToken)")
        
        // Set the APNs token for Firebase Messaging
        messaging.apnsToken = apnsToken
        print("✅ APNs token set for Firebase Messaging")
    }
}

// MARK: - App Delegate Extension for Remote Notifications
extension FirebaseMessagingDelegate: UNUserNotificationCenterDelegate {
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📱 Notification received in foreground: \(notification.request.content.title)")
        
        // Show notification even when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
    
    /// Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("📱 Notification tapped: \(response.notification.request.content.userInfo)")
        completionHandler()
    }
}

// MARK: - App Delegate Extension for Remote Notification Registration
extension FirebaseMessagingDelegate {
    
    /// Register for remote notifications
    func registerForRemoteNotifications() {
        // Don't set delegate here - let AppDelegate handle it
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                
                // Register for remote notifications
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("✅ Registered for remote notifications")
                }
            } else {
                print("❌ Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    /// Handle successful remote notification registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 APNs device token received: \(deviceToken)")
        
        // Set the APNs token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNs token set for Firebase Messaging")
    }
    
    /// Handle failed remote notification registration
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
