import SwiftUI
import FirebaseCore

@main
struct LocatedAppApp: App {
    // Initialize Firebase and background services when the app launches
    init() {
        FirebaseApp.configure()
        
        // Initialize background location manager
        _ = BackgroundLocationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}