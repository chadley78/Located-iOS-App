import Foundation
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Location Model
struct LocationData: Codable {
    var id: String?
    var familyId: String // Denormalized for security rules
    var lat: Double
    var lng: Double
    var accuracy: Double
    var timestamp: Date
    var address: String?
    var batteryLevel: Int?
    var isMoving: Bool
    var lastUpdated: Date
    
    init(familyId: String, lat: Double, lng: Double, accuracy: Double, timestamp: Date = Date(), address: String? = nil, batteryLevel: Int? = nil, isMoving: Bool = false) {
        self.familyId = familyId
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
        
        // Check initial permission status
        locationPermissionStatus = CLLocationManager.authorizationStatus()
        print("📍 Initial location permission status: \(locationPermissionStatus.rawValue)")
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
        #if canImport(UIKit)
        // Monitor battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryLevel()
            }
            .store(in: &cancellables)
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
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
        print("📍 Attempting to start location updates...")
        print("📍 Current permission status: \(locationPermissionStatus.rawValue)")
        
        guard locationPermissionStatus == .authorizedAlways else {
            print("❌ Cannot start location updates: permission not granted")
            errorMessage = "Always location permission is required for background tracking"
            return
        }
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services are disabled")
            errorMessage = "Location services are disabled. Please enable them in Settings."
            return
        }
        
        print("📍 Starting location updates...")
        isUpdatingLocation = true
        
        // Enable background location updates only after authorization
        locationManager.allowsBackgroundLocationUpdates = true
        
        // Start standard location updates
        locationManager.startUpdatingLocation()
        
        // Start significant location change monitoring for battery efficiency
        locationManager.startMonitoringSignificantLocationChanges()
        
        isLocationSharingEnabled = true
        print("📍 Location updates started successfully")
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Disable background location updates
        locationManager.allowsBackgroundLocationUpdates = false
        
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
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for location save")
            return
        }
        
        // Get user's familyId
        let userDoc = try? await Firestore.firestore().collection("users").document(userId).getDocument()
        let familyId = userDoc?.data()?["familyId"] as? String ?? "unknown"
        
        let locationData = LocationData(
            familyId: familyId,
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            address: address,
            batteryLevel: getCurrentBatteryLevel(),
            isMoving: location.speed > 1.0
        )
        
        do {
            let data = try Firestore.Encoder().encode(locationData)
            try await Firestore.firestore().collection("locations").document(userId).setData(data)
            print("📍 Location saved to Firestore: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } catch {
            print("❌ Error saving location to Firestore: \(error)")
        }
    }
    
    private func getCurrentBatteryLevel() -> Int {
        #if canImport(UIKit)
        let batteryLevel = UIDevice.current.batteryLevel
        return Int(batteryLevel * 100)
        #else
        return 100 // Mock battery level for macOS
        #endif
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
extension LocationService: @preconcurrency CLLocationManagerDelegate {
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
        
        // Handle specific error types
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorMessage = "Location access denied. Please enable location services in Settings."
            case .locationUnknown:
                errorMessage = "Unable to determine location. Please try again."
            case .network:
                errorMessage = "Network error. Please check your internet connection."
            case .headingFailure:
                errorMessage = "Compass heading unavailable."
            case .regionMonitoringDenied:
                errorMessage = "Region monitoring denied. Please enable location services."
            case .regionMonitoringFailure:
                errorMessage = "Region monitoring failed. Please try again."
            case .regionMonitoringSetupDelayed:
                errorMessage = "Region monitoring setup delayed. Please wait."
            case .regionMonitoringResponseDelayed:
                errorMessage = "Region monitoring response delayed. Please wait."
            case .geocodeFoundNoResult:
                errorMessage = "Address lookup failed. Location will be saved without address."
            case .geocodeFoundPartialResult:
                errorMessage = "Partial address found. Location saved with limited address info."
            case .geocodeCanceled:
                errorMessage = "Address lookup canceled."
            default:
                errorMessage = "Location error: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "Location update failed: \(error.localizedDescription)"
        }
        
        // Clear error message after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.errorMessage = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Location authorization changed to: \(status.rawValue)")
        locationPermissionStatus = status
        
        switch status {
        case .authorizedAlways:
            print("📍 Always permission granted, starting location updates")
            startLocationUpdates()
        case .authorizedWhenInUse:
            print("📍 When in use permission granted, requesting always permission")
            // Request upgrade to always authorization
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            print("📍 Location permission denied or restricted")
            stopLocationUpdates()
            errorMessage = "Location access denied. Please enable it in Settings for safety features."
        case .notDetermined:
            print("📍 Location permission not determined, requesting always permission")
            locationManager.requestAlwaysAuthorization()
        @unknown default:
            print("📍 Unknown location permission status")
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