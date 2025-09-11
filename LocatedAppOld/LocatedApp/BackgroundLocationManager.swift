import Foundation
import CoreLocation
import UIKit

// MARK: - Background Location Manager
class BackgroundLocationManager: NSObject, ObservableObject {
    static let shared = BackgroundLocationManager()
    
    private let locationManager = CLLocationManager()
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    override init() {
        super.init()
        setupLocationManager()
        setupBackgroundTaskHandling()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // 100 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func setupBackgroundTaskHandling() {
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
    }
    
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
    
    func startLocationUpdates() {
        guard CLLocationManager.authorizationStatus() == .authorizedAlways else {
            print("❌ Background location updates require 'Always' permission")
            return
        }
        
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        print("📍 Background location updates started")
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
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