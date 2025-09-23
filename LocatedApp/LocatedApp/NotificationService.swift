import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import UIKit

// MARK: - Notification Service
@MainActor
class NotificationService: NSObject, ObservableObject {
    private let db = Firestore.firestore()
    private let fcmRestService = FCMRestService()
    @Published var isRegistered = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
        guard let currentUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return
        }
        
        // Generate a valid FCM token using the REST service
        guard let fcmToken = await fcmRestService.generateFCMToken() else {
            await MainActor.run {
                self.errorMessage = "Failed to generate FCM token"
            }
            return
        }
        
        do {
            // Add token to user's FCM tokens array in Firestore
            try await db.collection("users").document(currentUser.uid).updateData([
                "fcmTokens": FieldValue.arrayUnion([fcmToken])
            ])
            
            await MainActor.run {
                self.isRegistered = true
                self.errorMessage = nil
                print("✅ FCM token registered: \(fcmToken)")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to register FCM token: \(error.localizedDescription)"
                print("❌ Failed to register FCM token: \(error)")
            }
        }
    }
    
    // MARK: - Test Notification
    
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
                        self.errorMessage = "No parents received notification: \(response.message)"
                        print("⚠️ \(response.message)")
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
