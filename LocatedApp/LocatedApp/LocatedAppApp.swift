import SwiftUI
import FirebaseCore

@main
struct LocatedAppApp: App {
    @StateObject private var familyService = FamilyService()
    
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
            ContentView()
                .environmentObject(familyService)
        }
    }
}