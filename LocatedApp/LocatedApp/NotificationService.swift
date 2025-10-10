import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import UIKit
import FirebaseMessaging

// MARK: - Notification Service
@MainActor
class NotificationService: NSObject, ObservableObject {
    private let db = Firestore.firestore()
    private let fcmRestService = FCMRestService()
    @Published var isRegistered = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showTestAlert = false
    
    override init() {
        super.init()
        setupNotificationCenter()
    }
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Notification Permission
    
    /// Request notification permissions from the user
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            if granted {
                await MainActor.run {
                    print("✅ Notification permission granted")
                }
                return true
            } else {
                await MainActor.run {
                    print("❌ Notification permission denied")
                }
                return false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to request notification permission: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - FCM Token Management
    
    
    /// Register FCM token with Firebase
    func registerFCMToken() async {
        // First, ensure we have notification permissions and register for remote notifications
        let hasPermission = await requestNotificationPermission()
        guard hasPermission else {
            await MainActor.run {
                // Optionally set an error message for the UI
                self.errorMessage = "Notification permission is required to receive alerts."
                print("⚠️ Notification permission denied. Cannot register FCM token.")
            }
            return
        }

        // Register for remote notifications (this is crucial for FCM to work)
        await MainActor.run {
            FirebaseMessagingDelegate.shared.registerForRemoteNotifications()
        }

        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return
        }
        
        print("⏳ Waiting for FCM token to be generated...")
        print("💡 The FCM token will be automatically saved when Firebase Messaging receives the APNs token")
        
        // Don't try to fetch the token immediately - let the MessagingDelegate handle it
        // The token will be saved to Firestore when didReceiveRegistrationToken is called
        
        // Try to get token if it already exists (for subsequent calls)
        do {
            // Add a small delay to allow APNs token to be received
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            let fcmToken = try await Messaging.messaging().token()
            
            // Save token to Firestore
            try await saveFCMTokenToFirestore(fcmToken, userId: currentUser.uid)
            
            await MainActor.run {
                self.isRegistered = true
                self.errorMessage = nil
                print("✅ FCM token registered: \(fcmToken)")
            }
        } catch {
            // If we can't get the token yet, that's okay - the delegate will handle it
            print("ℹ️ FCM token not ready yet: \(error.localizedDescription)")
            print("ℹ️ Token will be automatically registered when available via MessagingDelegate")
            
            await MainActor.run {
                // Don't show this as an error to the user since it's expected
                self.isRegistered = false
            }
        }
    }
    
    /// Save FCM token to Firestore
    func saveFCMTokenToFirestore(_ fcmToken: String, userId: String) async throws {
        // Add token to user's FCM tokens array in Firestore
        try await db.collection("users").document(userId).updateData([
            "fcmTokens": FieldValue.arrayUnion([fcmToken])
        ])
        print("✅ FCM token saved to Firestore: \(fcmToken)")
    }
    
    // MARK: - Test Notification
    
    /// Send a test notification to the same device (parent-to-self testing)
    func sendTestSelfNotification() async {
        print("🧪 Test self-notification requested")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.successMessage = nil
            self.showTestAlert = false
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "❌ Not logged in"
                self.isLoading = false
                self.showTestAlert = true
            }
            print("❌ Test failed: User not authenticated")
            return
        }
        
        // Get user info
        do {
            let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            guard let userData = userDoc.data(),
                  let userName = userData["name"] as? String,
                  let userType = userData["userType"] as? String,
                  let familyId = userData["familyId"] as? String else {
                await MainActor.run {
                    self.errorMessage = "❌ User profile incomplete"
                    self.isLoading = false
                    self.showTestAlert = true
                }
                print("❌ Test failed: User profile incomplete")
                return
            }
            
            print("🧪 Sending test self-notification for \(userName) in family \(familyId)")
            
            // Create test event that targets the same user
            let testEventId = "test-self-\(UUID().uuidString)"
            let event: [String: Any] = [
                "id": testEventId,
                "familyId": familyId,
                "childId": currentUser.uid, // Same user ID
                "childName": userName,
                "geofenceId": "test-self-geofence",
                "geofenceName": "🧪 Test Self Notification",
                "eventType": "enter",
                "timestamp": Timestamp(date: Date()),
                "location": [
                    "lat": 53.29526, "lng": -6.301476, "address": "Test Self Location, Dublin",
                    "accuracy": 5.0, "batteryLevel": getCurrentBatteryLevel(), "isMoving": false,
                    "lastUpdated": Timestamp(date: Date()), "familyId": familyId
                ]
            ]
            
            // Create the test event in Firestore (this will trigger the Cloud Function)
            try await db.collection("geofence_events").document(testEventId).setData(event)
            print("✅ Test self-event created in Firestore: \(testEventId)")
            
            // Auto-cleanup after 1 second
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            try? await db.collection("geofence_events").document(testEventId).delete()
            print("🧹 Test self-event cleaned up")
            
            await MainActor.run {
                self.successMessage = "✅ Test self-notification sent!\n\nCheck this device for notification."
                self.errorMessage = nil
                self.isLoading = false
                self.showTestAlert = true
            }
            print("✅ Test self-notification completed successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "❌ Test failed: \(error.localizedDescription)"
                self.isLoading = false
                self.showTestAlert = true
            }
            print("❌ Test self-notification failed: \(error)")
        }
    }
    
    /// Send a test notification with debug info to parent devices
    func sendTestNotification() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
                self.isLoading = false
            }
            return
        }
        
        // Get family ID from user document
        var familyId: String?
        do {
            let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            if let userData = userDoc.data() {
                familyId = userData["familyId"] as? String
            }
        } catch {
            print("❌ Failed to get family ID: \(error)")
        }
        
        guard let familyId = familyId else {
            await MainActor.run {
                self.errorMessage = "No family ID found for user"
            }
            return
        }
        
        // Get debug information
        let debugInfo = await getDebugInfo()
        
        do {
            // Use the FCM REST service to send the notification
            let response = try await fcmRestService.sendNotification(
                childId: currentUser.uid,
                childName: currentUser.displayName ?? "Test Child",
                familyId: familyId,
                debugInfo: debugInfo
            )
            
            await MainActor.run {
                if response.success {
                    if response.successCount > 0 {
                        self.errorMessage = nil
                        print("✅ Debug notification sent successfully to \(response.successCount) parent(s)")
                        
                        // Show notification content if available
                        if let debugInfo = response.debugInfo {
                            if let title = debugInfo["notificationTitle"] as? String,
                               let body = debugInfo["notificationBody"] as? String {
                                print("📱 Notification that would be sent:")
                                print("   Title: \(title)")
                                print("   Body: \(body)")
                                
                                // Also show in the UI
                                self.errorMessage = "✅ Notification sent!\nTitle: \(title)\nBody: \(body)"
                            }
                        }
                    } else {
                        var detailedMessage = response.message
                        // Check for detailed token error information
                        if let debugInfo = response.debugInfo,
                           let attemptedTokens = debugInfo["tokensAttempted"] as? [String] {
                            let tokensString = attemptedTokens.joined(separator: "\n")
                            detailedMessage += "\n\nInvalid Tokens Found:\n\(tokensString)"
                        }
                        self.errorMessage = "No parents received notification: \(detailedMessage)"
                        print("⚠️ \(detailedMessage)")
                    }
                } else {
                    self.errorMessage = "Notification failed: \(response.message)"
                    print("❌ \(response.message)")
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to send test notification: \(error.localizedDescription)"
                print("❌ Failed to send test notification: \(error)")
                self.isLoading = false
            }
        }
    }
    
    /// Get current debug information
    private func getDebugInfo() async -> [String: Any] {
        var debugInfo: [String: Any] = [:]
        
        // Get current location if available
        if let location = await getCurrentLocation() {
            debugInfo["latitude"] = location.coordinate.latitude
            debugInfo["longitude"] = location.coordinate.longitude
            debugInfo["accuracy"] = location.horizontalAccuracy
            debugInfo["isMoving"] = location.speed > 1.0
        }
        
        // Get battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        debugInfo["batteryLevel"] = UIDevice.current.batteryLevel
        
        // Get device info
        debugInfo["deviceModel"] = getDeviceModel()
        debugInfo["systemVersion"] = UIDevice.current.systemVersion
        debugInfo["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        // Get user info
        if let currentUser = Auth.auth().currentUser {
            debugInfo["userId"] = currentUser.uid
            debugInfo["userEmail"] = currentUser.email
            debugInfo["userName"] = currentUser.displayName
        }
        
        // Get family info
        if let currentUser = Auth.auth().currentUser {
            do {
                let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
                if let userData = userDoc.data() {
                    debugInfo["familyId"] = userData["familyId"] as? String
                }
            } catch {
                print("❌ Failed to get family info: \(error)")
            }
        }
        
        return debugInfo
    }
    
    /// Get current location from LocationService
    private func getCurrentLocation() async -> CLLocation? {
        // Get the actual current location from LocationService
        // We need to access the LocationService instance
        return await MainActor.run {
            // This will be set by the parent view
            return currentLocation
        }
    }
    
    // Property to hold the current location
    private var currentLocation: CLLocation?
    
    // Method to set the current location
    func setCurrentLocation(_ location: CLLocation?) {
        self.currentLocation = location
    }
    
    // Get the actual device model
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        
        let modelName = modelCode ?? "Unknown"
        
        // Map common device codes to readable names
        switch modelName {
        case "iPhone14,7": return "iPhone 13"
        case "iPhone14,8": return "iPhone 13"
        case "iPhone15,2": return "iPhone 14"
        case "iPhone15,3": return "iPhone 14 Pro"
        case "iPhone15,4": return "iPhone 14"
        case "iPhone15,5": return "iPhone 14 Plus"
        case "iPhone16,1": return "iPhone 15"
        case "iPhone16,2": return "iPhone 15 Plus"
        case "iPhone16,3": return "iPhone 15 Pro"
        case "iPhone16,4": return "iPhone 15 Pro Max"
        case "iPad13,1": return "iPad Air (5th generation)"
        case "iPad13,2": return "iPad Air (5th generation)"
        case "iPad14,1": return "iPad mini (6th generation)"
        case "iPad14,2": return "iPad mini (6th generation)"
        default: return modelName
        }
    }
    
    // MARK: - Test Geofence Notification
    
    /// Send a test geofence notification to parent devices
    func sendTestGeofenceNotification() async {
        print("🧪 Test notification requested")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.successMessage = nil
            self.showTestAlert = false
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "❌ Not logged in"
                self.isLoading = false
                self.showTestAlert = true
            }
            print("❌ Test failed: User not authenticated")
            return
        }
        
        // Get user info
        do {
            let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            guard let userData = userDoc.data(),
                  let familyId = userData["familyId"] as? String,
                  let childName = userData["name"] as? String else {
                await MainActor.run {
                    self.errorMessage = "❌ Could not find family information"
                    self.isLoading = false
                    self.showTestAlert = true
                }
                print("❌ Test failed: Missing user or family data")
                return
            }
            
            print("🧪 Sending test notification for \(childName) in family \(familyId)")
            
            // Use a unique ID for this test
            let testEventId = "test-\(UUID().uuidString)"
            
            // Create a test geofence event in Firestore
            let event: [String: Any] = [
                "id": testEventId,
                "familyId": familyId,
                "childId": currentUser.uid,
                "childName": childName,
                "geofenceId": "test-geofence",
                "geofenceName": "🧪 Test Notification",
                "eventType": "enter",
                "timestamp": Timestamp(date: Date()),
                "location": [
                    "lat": 53.29526,
                    "lng": -6.301476,
                    "address": "Test Location, Dublin",
                    "accuracy": 5.0,
                    "batteryLevel": getCurrentBatteryLevel(),
                    "isMoving": false,
                    "lastUpdated": Timestamp(date: Date()),
                    "familyId": familyId
                ]
            ]
            
            // Create the event
            try await db.collection("geofence_events").document(testEventId).setData(event)
            print("✅ Test event created in Firestore: \(testEventId)")
            
            // Wait a moment for Cloud Function to process
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Clean up the test event
            try? await db.collection("geofence_events").document(testEventId).delete()
            print("🧹 Test event cleaned up")
            
            await MainActor.run {
                self.successMessage = "✅ Test notification sent!\n\nCheck parent device for notification."
                self.errorMessage = nil
                self.isLoading = false
                self.showTestAlert = true
            }
            print("✅ Test notification completed successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "❌ Failed: \(error.localizedDescription)"
                self.isLoading = false
                self.showTestAlert = true
            }
            print("❌ Test failed with error: \(error)")
        }
    }
    
    // Helper to get current battery level
    private func getCurrentBatteryLevel() -> Int {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        return Int(batteryLevel * 100)
        #else
        return 100
        #endif
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
        completionHandler()
    }
}

// MARK: - Import CoreLocation for location functionality
import CoreLocation
