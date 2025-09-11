import SwiftUI
import FirebaseCore

@main
struct LocatedAppApp: App {
    // Initialize background services when the app launches
    init() {
        // Initialize background location manager
        _ = BackgroundLocationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Configure Firebase when the app appears
                    if FirebaseApp.app() == nil {
                        FirebaseApp.configure()
                        print("✅ Firebase configured successfully")
                    } else {
                        print("✅ Firebase already configured")
                    }
                }
        }
    }
}