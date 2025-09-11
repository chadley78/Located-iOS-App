import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

// MARK: - Location Model
struct LocationData: Codable {
    @DocumentID var id: String?
    var lat: Double
    var lng: Double
    var accuracy: Double
    var timestamp: Date
    var address: String?
    var batteryLevel: Int?
    var isMoving: Bool
    var lastUpdated: Date
    
    init(lat: Double, lng: Double, accuracy: Double, timestamp: Date = Date(), address: String? = nil, batteryLevel: Int? = nil, isMoving: Bool = false) {
        self.lat = lat
        self.lng = lng
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.address = address
        self.batteryLevel = batteryLevel
        self.isMoving = isMoving
        self.lastUpdated = Date()
    }
}

// MARK: - Location Service
@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationSharingEnabled = false
    @Published var lastLocationUpdate: Date?
    @Published var errorMessage: String?
    @Published var isUpdatingLocation = false
    
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private let geocoder = CLGeocoder()
    private var cancellables = Set<AnyCancellable>()
    
    // Location update settings
    private let locationUpdateInterval: TimeInterval = 30 // 30 seconds
    private let significantLocationChangeThreshold: CLLocationDistance = 100 // 100 meters
    private var lastSignificantLocation: CLLocation?
    
    override init() {
        super.init()
        setupLocationManager()
        setupBatteryMonitoring()
        setupBackgroundLocationHandling()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = significantLocationChangeThreshold
        
        // Request appropriate permissions based on current status
        requestLocationPermission()
    }
    
    private func setupBatteryMonitoring() {
        // Monitor battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryLevel()
            }
            .store(in: &cancellables)
        
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    private func setupBackgroundLocationHandling() {
        // Listen for background location updates
        NotificationCenter.default.publisher(for: .backgroundLocationUpdate)
            .sink { [weak self] notification in
                if let location = notification.userInfo?["location"] as? CLLocation {
                    self?.processLocationUpdate(location)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Permission Management
    func requestLocationPermission() {
        switch locationPermissionStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            // Permission denied, show alert
            errorMessage = "Location access is required for safety features. Please enable it in Settings."
        case .authorizedWhenInUse:
            // Request upgrade to always authorization
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            // Permission granted, start location updates
            startLocationUpdates()
        @unknown default:
            break
        }
    }
    
    // MARK: - Location Updates
    func startLocationUpdates() {
        guard locationPermissionStatus == .authorizedAlways else {
            errorMessage = "Always location permission is required for background tracking"
            return
        }
        
        isUpdatingLocation = true
        
        // Start standard location updates
        locationManager.startUpdatingLocation()
        
        // Start significant location change monitoring for battery efficiency
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Start background location updates
        if #available(iOS 14.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        
        isLocationSharingEnabled = true
        print("📍 Location updates started")
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        if #available(iOS 14.0, *) {
            locationManager.allowsBackgroundLocationUpdates = false
        }
        
        isUpdatingLocation = false
        isLocationSharingEnabled = false
        print("📍 Location updates stopped")
    }
    
    // MARK: - Location Data Processing
    private func processLocationUpdate(_ location: CLLocation) {
        // Check if this is a significant location change
        guard isSignificantLocationChange(location) else {
            return
        }
        
        currentLocation = location
        lastLocationUpdate = Date()
        
        // Reverse geocode to get address
        reverseGeocodeLocation(location) { [weak self] address in
            Task { @MainActor in
                await self?.saveLocationToFirestore(location: location, address: address)
            }
        }
        
        lastSignificantLocation = location
    }
    
    private func isSignificantLocationChange(_ location: CLLocation) -> Bool {
        guard let lastLocation = lastSignificantLocation else {
            return true // First location update
        }
        
        let distance = location.distance(from: lastLocation)
        let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        
        // Consider it significant if:
        // 1. Distance is greater than threshold, OR
        // 2. Time interval is greater than update interval
        return distance >= significantLocationChangeThreshold || timeInterval >= locationUpdateInterval
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation, completion: @escaping (String?) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error)")
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            // Format address
            var addressComponents: [String] = []
            
            if let streetNumber = placemark.subThoroughfare {
                addressComponents.append(streetNumber)
            }
            if let streetName = placemark.thoroughfare {
                addressComponents.append(streetName)
            }
            if let city = placemark.locality {
                addressComponents.append(city)
            }
            if let state = placemark.administrativeArea {
                addressComponents.append(state)
            }
            if let zipCode = placemark.postalCode {
                addressComponents.append(zipCode)
            }
            
            let address = addressComponents.isEmpty ? nil : addressComponents.joined(separator: " ")
            completion(address)
        }
    }
    
    // MARK: - Firestore Integration
    private func saveLocationToFirestore(location: CLLocation, address: String?) async {
        guard let userId = await getCurrentUserId() else {
            print("❌ No authenticated user found")
            return
        }
        
        let locationData = LocationData(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            address: address,
            batteryLevel: getCurrentBatteryLevel(),
            isMoving: location.speed > 1.0 // Consider moving if speed > 1 m/s
        )
        
        do {
            try await db.collection("locations").document(userId).setData(from: locationData, merge: true)
            print("✅ Location saved to Firestore: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } catch {
            print("❌ Error saving location to Firestore: \(error)")
            errorMessage = "Failed to save location data"
        }
    }
    
    private func getCurrentUserId() async -> String? {
        // This would typically come from your authentication service
        // For now, we'll use a placeholder
        return Auth.auth().currentUser?.uid
    }
    
    private func getCurrentBatteryLevel() -> Int {
        let batteryLevel = UIDevice.current.batteryLevel
        return Int(batteryLevel * 100)
    }
    
    private func updateBatteryLevel() {
        // Battery level will be included in the next location update
        print("🔋 Battery level updated: \(getCurrentBatteryLevel())%")
    }
    
    // MARK: - Public Methods
    func toggleLocationSharing() {
        if isLocationSharingEnabled {
            stopLocationUpdates()
        } else {
            requestLocationPermission()
        }
    }
    
    func getLocationPermissionStatusString() -> String {
        switch locationPermissionStatus {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorizedWhenInUse:
            return "When In Use"
        case .authorizedAlways:
            return "Always"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out old or inaccurate locations
        guard location.timestamp.timeIntervalSinceNow > -30 && location.horizontalAccuracy < 100 else {
            return
        }
        
        processLocationUpdate(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error)")
        errorMessage = "Location update failed: \(error.localizedDescription)"
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationPermissionStatus = status
        
        switch status {
        case .authorizedAlways:
            startLocationUpdates()
        case .authorizedWhenInUse:
            // Request upgrade to always authorization
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            stopLocationUpdates()
            errorMessage = "Location access denied. Please enable it in Settings for safety features."
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("📍 Location updates paused")
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("📍 Location updates resumed")
    }
}