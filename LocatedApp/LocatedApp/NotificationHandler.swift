import Foundation
import SwiftUI

class NotificationHandler: ObservableObject {
    static let shared = NotificationHandler()
    
    @Published var pendingChildId: String?
    @Published var pendingGeofenceId: String?
    @Published var pendingEventType: String?
    
    private init() {}
    
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        print("📱 NotificationHandler - Processing notification tap: \(userInfo)")
        
        // Parse notification data
        guard let type = userInfo["type"] as? String,
              type == "geofence_event" else {
            print("📱 NotificationHandler - Not a geofence event notification")
            return
        }
        
        guard let childId = userInfo["childId"] as? String else {
            print("📱 NotificationHandler - No childId in notification")
            return
        }
        
        let geofenceId = userInfo["geofenceId"] as? String
        let eventType = userInfo["eventType"] as? String
        
        print("📱 NotificationHandler - Parsed notification data:")
        print("  - Child ID: \(childId)")
        print("  - Geofence ID: \(geofenceId ?? "nil")")
        print("  - Event Type: \(eventType ?? "nil")")
        
        // Store the pending navigation data
        DispatchQueue.main.async {
            print("📱 NotificationHandler - Setting pendingChildId to: \(childId)")
            self.pendingChildId = childId
            self.pendingGeofenceId = geofenceId
            self.pendingEventType = eventType
            print("📱 NotificationHandler - pendingChildId is now: \(self.pendingChildId ?? "nil")")
        }
    }
    
    func clearPendingNotification() {
        DispatchQueue.main.async {
            self.pendingChildId = nil
            self.pendingGeofenceId = nil
            self.pendingEventType = nil
        }
    }
}
