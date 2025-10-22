import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Background Location Manager
class BackgroundLocationManager: NSObject, ObservableObject {
    static let shared = BackgroundLocationManager()
    
    private let locationManager = CLLocationManager()
    #if canImport(UIKit)
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    override init() {
        super.init()
        setupLocationManager()
        setupBackgroundTaskHandling()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // Highest accuracy for tracking
        locationManager.distanceFilter = 0 // No distance filter - we handle filtering ourselves
        locationManager.pausesLocationUpdatesAutomatically = false
        // Note: allowsBackgroundLocationUpdates will be set only after authorization
    }
    
    private func setupBackgroundTaskHandling() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    #if canImport(UIKit)
    @objc private func appDidEnterBackground() {
        startBackgroundTask()
        startLocationUpdates()
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
    }
    
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing background task
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "LocationTracking") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    #endif
    
    func startLocationUpdates() {
        guard CLLocationManager.authorizationStatus() == .authorizedAlways else {
            print("❌ Background location updates require 'Always' permission")
            return
        }
        
        // Enable background location updates only after authorization
        locationManager.allowsBackgroundLocationUpdates = true
        
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        print("📍 Background location updates started")
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Disable background location updates
        locationManager.allowsBackgroundLocationUpdates = false
        
        print("📍 Background location updates stopped")
    }
}

// MARK: - CLLocationManagerDelegate
extension BackgroundLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out old or inaccurate locations
        guard location.timestamp.timeIntervalSinceNow > -30 && location.horizontalAccuracy < 100 else {
            return
        }
        
        print("📍 Background location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Notify the main location service
        NotificationCenter.default.post(
            name: .backgroundLocationUpdate,
            object: nil,
            userInfo: ["location": location]
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Background location manager failed: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Background location authorization changed: \(status.rawValue)")
        
        if status == .authorizedAlways {
            startLocationUpdates()
        } else {
            stopLocationUpdates()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let backgroundLocationUpdate = Notification.Name("backgroundLocationUpdate")
}