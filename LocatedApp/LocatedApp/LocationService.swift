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
    
    var authenticationService: AuthenticationService?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var cancellables = Set<AnyCancellable>()
    private var periodicLocationTimer: Timer?
    
    // Geofence state tracking
    private var lastKnownGeofenceId: String? // Track which geofence child is currently in
    private var cachedGeofences: [Geofence] = [] // Cache of active geofences for this family
    
    // Location update settings
    private let locationUpdateInterval: TimeInterval = 30 // 30 seconds
    private let significantLocationChangeThreshold: CLLocationDistance = 100 // 100 meters
    private var lastSignificantLocation: CLLocation?
    private var lastFirestoreUpdateTime: Date?
    
    // Periodic update intervals for different scenarios
    private let periodicUpdateIntervalMoving: TimeInterval = 120 // 2 minutes when moving
    private let periodicUpdateIntervalStationary: TimeInterval = 300 // 5 minutes when stationary
    private let periodicUpdateIntervalLowBattery: TimeInterval = 600 // 10 minutes when battery < 20%
    private let periodicUpdateIntervalVeryLowBattery: TimeInterval = 900 // 15 minutes when battery < 10%
    private let lowBatteryThreshold: Int = 20 // Battery percentage threshold
    private let veryLowBatteryThreshold: Int = 10 // Critical battery threshold
    
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
        
        // Start periodic location timer for regular updates
        setupPeriodicLocationTimer()
        
        // Fetch geofences for containment checking
        Task {
            await fetchGeofences()
        }
        
        isLocationSharingEnabled = true
        print("📍 Location updates started successfully")
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Stop and cleanup periodic timer
        periodicLocationTimer?.invalidate()
        periodicLocationTimer = nil
        print("⏰ Periodic location timer stopped")
        
        // Disable background location updates
        locationManager.allowsBackgroundLocationUpdates = false
        
        isUpdatingLocation = false
        isLocationSharingEnabled = false
        print("📍 Location updates stopped")
    }
    
    // MARK: - Location Data Processing
    private func processLocationUpdate(_ location: CLLocation) {
        print("📍 Location update received: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("📍 Location accuracy: \(location.horizontalAccuracy)m")
        print("📍 Location timestamp: \(location.timestamp)")
        
        // Check if this is a significant location change
        guard isSignificantLocationChange(location) else {
            print("📍 Location change not significant - ignoring")
            return
        }
        
        print("📍 Significant location change detected - processing")
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
            print("📍 First location update - treating as significant")
            return true // First location update
        }
        
        let distance = location.distance(from: lastLocation)
        let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        
        print("📍 Distance from last location: \(distance)m (threshold: \(significantLocationChangeThreshold)m)")
        print("📍 Time since last location: \(timeInterval)s (threshold: \(locationUpdateInterval)s)")
        
        // Consider it significant if:
        // 1. Distance is greater than threshold, OR
        // 2. Time interval is greater than update interval
        let isSignificant = distance >= significantLocationChangeThreshold || timeInterval >= locationUpdateInterval
        print("📍 Location change significant: \(isSignificant)")
        
        return isSignificant
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
            lastFirestoreUpdateTime = Date() // Track when we last updated Firestore
            print("📍 Location saved to Firestore: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Check geofence containment after saving location
            await checkGeofenceContainment(location: location)
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
    
    // MARK: - Periodic Location Updates
    
    /// Determines the appropriate update interval based on movement and battery state
    private func getCurrentMovementState() -> TimeInterval {
        let batteryLevel = getCurrentBatteryLevel()
        
        // Check battery level first (highest priority)
        if batteryLevel < veryLowBatteryThreshold {
            print("🔋 Very low battery (\(batteryLevel)%) - using \(periodicUpdateIntervalVeryLowBattery)s interval")
            return periodicUpdateIntervalVeryLowBattery
        } else if batteryLevel < lowBatteryThreshold {
            print("🔋 Low battery (\(batteryLevel)%) - using \(periodicUpdateIntervalLowBattery)s interval")
            return periodicUpdateIntervalLowBattery
        }
        
        // Check if moving (based on last known location speed)
        if let location = currentLocation, location.speed > 1.0 {
            print("🚶 Child moving - using \(periodicUpdateIntervalMoving)s interval")
            return periodicUpdateIntervalMoving
        } else {
            print("🛑 Child stationary - using \(periodicUpdateIntervalStationary)s interval")
            return periodicUpdateIntervalStationary
        }
    }
    
    /// Requests a periodic location update and saves to Firestore
    private func requestPeriodicLocationUpdate() {
        print("⏰ Periodic location update triggered")
        
        // Check if enough time has passed since last Firestore update
        // Allow 30 second tolerance to account for timer precision and race conditions
        let timingTolerance: TimeInterval = 30
        
        if let lastUpdate = lastFirestoreUpdateTime {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            let requiredInterval = getCurrentMovementState()
            
            // Skip only if we're more than 30 seconds early
            if timeSinceLastUpdate < (requiredInterval - timingTolerance) {
                print("⏰ Skipping update - only \(Int(timeSinceLastUpdate))s since last update (need \(Int(requiredInterval))s)")
                return
            }
        }
        
        if let currentLocation = currentLocation {
            print("⏰ Using current location for periodic update")
            // Use current location and save to Firestore
            Task {
                await saveLocationToFirestore(location: currentLocation, address: nil)
            }
        } else {
            print("⏰ No current location, requesting fresh location")
            // Request a fresh location update
            locationManager.requestLocation()
        }
    }
    
    /// Sets up the periodic location timer with adaptive intervals
    private func setupPeriodicLocationTimer() {
        // Invalidate any existing timer
        periodicLocationTimer?.invalidate()
        
        // Get the appropriate interval based on current state
        let interval = getCurrentMovementState()
        
        print("⏰ Setting up periodic location timer with interval: \(Int(interval))s")
        
        // Create a repeating timer on the main run loop
        // Using .common mode ensures it runs even during UI interactions
        periodicLocationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.requestPeriodicLocationUpdate()
                // Restart timer with potentially new interval (adaptive behavior)
                self?.setupPeriodicLocationTimer()
            }
        }
        
        // Ensure timer continues in background
        if let timer = periodicLocationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // MARK: - Force Location Update
    func forceLocationUpdate() {
        print("📍 Force location update requested")
        
        if let currentLocation = currentLocation {
            print("📍 Using current location for immediate update")
            // Force save current location immediately
            lastLocationUpdate = Date()
            Task {
                await saveLocationToFirestore(location: currentLocation, address: nil)
            }
        } else {
            print("📍 No current location, requesting fresh location")
            // Request a fresh location update
            locationManager.requestLocation()
        }
    }
    
    // MARK: - Geofence Containment Checking
    
    /// Fetch active geofences for the child's family
    func fetchGeofences() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for geofence fetch")
            return
        }
        
        do {
            // Get user's familyId
            let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
            guard let familyId = userDoc.data()?["familyId"] as? String else {
                print("📍 No family ID for user - skipping geofence fetch")
                return
            }
            
            // Fetch active geofences for this family
            let snapshot = try await Firestore.firestore().collection("geofences")
                .whereField("familyId", isEqualTo: familyId)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            let geofences = snapshot.documents.compactMap { doc -> Geofence? in
                try? doc.data(as: Geofence.self)
            }
            
            await MainActor.run {
                self.cachedGeofences = geofences
                print("📍 Fetched \(geofences.count) geofences for family \(familyId)")
            }
            
        } catch {
            print("❌ Error fetching geofences: \(error)")
        }
    }
    
    /// Check if current location is inside any geofences and log events if state changed
    private func checkGeofenceContainment(location: CLLocation) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Find which geofence (if any) the child is currently in
        var currentGeofenceId: String? = nil
        var currentGeofence: Geofence? = nil
        
        for geofence in cachedGeofences {
            let geofenceCenter = CLLocation(latitude: geofence.latitude, longitude: geofence.longitude)
            let distance = location.distance(from: geofenceCenter)
            
            if distance <= geofence.radius {
                // Child is inside this geofence
                currentGeofenceId = geofence.id
                currentGeofence = geofence
                print("📍 Child is inside geofence: \(geofence.name) (distance: \(Int(distance))m, radius: \(Int(geofence.radius))m)")
                break // Only track one geofence at a time
            }
        }
        
        // Check if state changed
        if currentGeofenceId != lastKnownGeofenceId {
            // State changed - log events
            
            if let lastId = lastKnownGeofenceId, let exitedGeofence = cachedGeofences.first(where: { $0.id == lastId }) {
                // Child exited a geofence
                print("📍 Synthetic EXIT event: \(exitedGeofence.name)")
                await logSyntheticGeofenceEvent(geofence: exitedGeofence, eventType: .exit, location: location)
            }
            
            if let enteredGeofence = currentGeofence {
                // Child entered a geofence
                print("📍 Synthetic ENTER event: \(enteredGeofence.name)")
                await logSyntheticGeofenceEvent(geofence: enteredGeofence, eventType: .enter, location: location)
            }
            
            // Update last known state
            await MainActor.run {
                self.lastKnownGeofenceId = currentGeofenceId
            }
        }
    }
    
    /// Log a synthetic geofence event (triggered by location check, not iOS boundary crossing)
    private func logSyntheticGeofenceEvent(geofence: Geofence, eventType: GeofenceEventType, location: CLLocation) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Get user's name
            let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
            let userName = userDoc.data()?["name"] as? String ?? "Unknown"
            
            let event: [String: Any] = [
                "id": UUID().uuidString,
                "familyId": geofence.familyId,
                "childId": userId,
                "childName": userName,
                "geofenceId": geofence.id,
                "geofenceName": geofence.name,
                "eventType": eventType.rawValue,
                "timestamp": Timestamp(date: Date()),
                "location": [
                    "lat": location.coordinate.latitude,
                    "lng": location.coordinate.longitude,
                    "timestamp": Timestamp(date: location.timestamp),
                    "accuracy": location.horizontalAccuracy,
                    "batteryLevel": getCurrentBatteryLevel(),
                    "isMoving": location.speed > 1.0,
                    "lastUpdated": Timestamp(date: Date()),
                    "familyId": geofence.familyId
                ]
            ]
            
            try await Firestore.firestore().collection("geofence_events").document(event["id"] as! String).setData(event)
            print("✅ Logged synthetic geofence event: \(eventType.rawValue) \(geofence.name)")
            
        } catch {
            print("❌ Error logging synthetic geofence event: \(error)")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { 
            print("📍 No location in update")
            return 
        }
        
        print("📍 CLLocationManager didUpdateLocations: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("📍 Location age: \(location.timestamp.timeIntervalSinceNow)s")
        print("📍 Location accuracy: \(location.horizontalAccuracy)m")
        
        // Filter out old or inaccurate locations
        guard location.timestamp.timeIntervalSinceNow > -30 && location.horizontalAccuracy < 100 else {
            print("📍 Location filtered out - too old or inaccurate")
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