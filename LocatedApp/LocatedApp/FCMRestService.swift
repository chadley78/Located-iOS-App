import Foundation
import UserNotifications
import UIKit

// MARK: - FCM REST Service
@MainActor
class FCMRestService: NSObject, ObservableObject {
    @Published var fcmToken: String?
    @Published var isRegistered = false
    @Published var errorMessage: String?
    
    private let cloudFunctionEndpoint = "https://us-central1-located-d9dce.cloudfunctions.net/sendDebugNotification"
    
    override init() {
        super.init()
    }
    
    // MARK: - FCM Token Generation
    
    /// Generate a valid FCM token using the REST API
    func generateFCMToken() async -> String? {
        do {
            // Request notification permission first
            let hasPermission = await requestNotificationPermission()
            guard hasPermission else {
                await MainActor.run {
                    self.errorMessage = "Notification permission required"
                }
                return nil
            }
            
            // Generate a valid FCM token using the REST API
            let token = try await requestFCMTokenFromServer()
            await MainActor.run {
                self.fcmToken = token
                self.isRegistered = true
                self.errorMessage = nil
            }
            return token
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate FCM token: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    /// Request notification permissions
    private func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            return false
        }
    }
    
    /// Request FCM token from Firebase using REST API
    private func requestFCMTokenFromServer() async throws -> String {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Call our Cloud Function to generate a valid FCM token
        let url = URL(string: "https://us-central1-located-d9dce.cloudfunctions.net/generateFCMToken")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "deviceId": deviceId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FCMError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FCMError.httpError(httpResponse.statusCode, errorMessage)
        }
        
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let fcmToken = responseData?["fcmToken"] as? String else {
            throw FCMError.invalidResponse
        }
        
        return fcmToken
    }
    
    // MARK: - Send Notification via Cloud Function
    
    /// Send a notification using our Cloud Function
    func sendNotification(childId: String, childName: String, familyId: String, debugInfo: [String: Any]) async throws -> CloudFunctionResponse {
        let url = URL(string: cloudFunctionEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "childId": childId,
            "childName": childName,
            "familyId": familyId,
            "debugInfo": debugInfo
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FCMError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FCMError.httpError(httpResponse.statusCode, errorMessage)
        }
        
        // Parse the response manually to handle mixed types in debugInfo
        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let responseData = responseData else {
            throw FCMError.invalidResponse
        }
        
        let cloudResponse = CloudFunctionResponse(
            success: responseData["success"] as? Bool ?? false,
            message: responseData["message"] as? String ?? "Unknown response",
            successCount: responseData["successCount"] as? Int ?? 0,
            failureCount: responseData["failureCount"] as? Int ?? 0,
            error: responseData["error"] as? String,
            debugInfo: responseData["debugInfo"] as? [String: Any]
        )
        
        return cloudResponse
    }
}

// MARK: - Cloud Function Response Models
struct CloudFunctionResponse {
    let success: Bool
    let message: String
    let successCount: Int
    let failureCount: Int
    let error: String?
    let debugInfo: [String: Any]?
    
    init(success: Bool, message: String, successCount: Int, failureCount: Int, error: String?, debugInfo: [String: Any]?) {
        self.success = success
        self.message = message
        self.successCount = successCount
        self.failureCount = failureCount
        self.error = error
        self.debugInfo = debugInfo
    }
}

// MARK: - FCM Errors
enum FCMError: LocalizedError {
    case noTokens
    case invalidResponse
    case httpError(Int, String)
    case serverKeyNotFound
    
    var errorDescription: String? {
        switch self {
        case .noTokens:
            return "No FCM tokens provided"
        case .invalidResponse:
            return "Invalid response from FCM server"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .serverKeyNotFound:
            return "FCM Server Key not found"
        }
    }
}
