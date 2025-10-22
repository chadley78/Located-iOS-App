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
    private var geofenceListener: ListenerRegistration? // Real-time listener for geofence changes
    
    // Flag to force save next location (used after accepting invitation)
    private var shouldSaveNextLocation = false
    
    // Location update settings - Optimized for high-fidelity tracking
    private let locationUpdateInterval: TimeInterval = 10 // 10 seconds (was 30s)
    private let significantLocationChangeThreshold: CLLocationDistance = 25 // 25 meters (was 100m)
    private var lastSignificantLocation: CLLocation?
    private var lastFirestoreUpdateTime: Date?
    
    // Periodic update intervals for different scenarios - Much more frequent
    private let periodicUpdateIntervalMoving: TimeInterval = 30 // 30 seconds when moving (was 2min)
    private let periodicUpdateIntervalStationary: TimeInterval = 120 // 2 minutes when stationary (was 5min)
    private let periodicUpdateIntervalLowBattery: TimeInterval = 300 // 5 minutes when battery < 20% (was 10min)
    private let periodicUpdateIntervalVeryLowBattery: TimeInterval = 600 // 10 minutes when battery < 10% (was 15min)
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
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // Highest accuracy for tracking
        locationManager.distanceFilter = 0 // No distance filter - we handle filtering ourselves
        locationManager.pausesLocationUpdatesAutomatically = false // Keep updating even when stationary
        
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
    
    /// Request Always permission - the delegate method will handle starting background location
    func requestAlwaysPermissionAndStartBackground() {
        print("📍 Requesting Always permission")
        
        let currentStatus = CLLocationManager.authorizationStatus()
        print("📍 Current authorization status: \(currentStatus.rawValue)")
        
        // Request Always authorization
        // The delegate method (didChangeAuthorization) will handle the response
        locationManager.requestAlwaysAuthorization()
        
        print("📍 Permission request sent - waiting for user response")
    }
    
    // MARK: - Location Updates
    func startLocationUpdates() {
        print("📍 Attempting to start location updates...")
        print("📍 Current permission status: \(locationPermissionStatus.rawValue)")
        
        // Prevent duplicate starts
        if isUpdatingLocation {
            print("⚠️ Location updates already running - skipping duplicate start")
            return
        }
        
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
        
        // Set up real-time geofence listener
        Task {
            await setupGeofenceListener()
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
        
        // Stop geofence listener
        geofenceListener?.remove()
        geofenceListener = nil
        print("📍 Geofence listener stopped")
        
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
        
        // Check if we should force save this location (e.g., after accepting invitation)
        let shouldForceSave = shouldSaveNextLocation
        if shouldForceSave {
            print("📍 Force save flag set - will save this location immediately")
            shouldSaveNextLocation = false // Reset flag
        }
        
        // Check if this is a significant location change (or forced)
        guard shouldForceSave || isSignificantLocationChange(location) else {
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
            
            // Save current location (overwrites previous)
            try await Firestore.firestore().collection("locations").document(userId).setData(data)
            lastFirestoreUpdateTime = Date() // Track when we last updated Firestore
            print("📍 Location saved to Firestore: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Also save to location history (append-only)
            try await Firestore.firestore().collection("location_history").addDocument(data: [
                "childId": userId,
                "familyId": familyId,
                "lat": location.coordinate.latitude,
                "lng": location.coordinate.longitude,
                "accuracy": location.horizontalAccuracy,
                "timestamp": FieldValue.serverTimestamp(),
                "address": address ?? "",
                "batteryLevel": getCurrentBatteryLevel(),
                "isMoving": location.speed > 1.0
            ])
            print("📍 Location history saved")
            
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
        // Always get the current status from CLLocationManager to ensure accuracy
        let currentStatus = CLLocationManager.authorizationStatus()
        
        // Update our stored status if it's different
        if currentStatus != locationPermissionStatus {
            print("📍 Permission status mismatch - updating from \(locationPermissionStatus.rawValue) to \(currentStatus.rawValue)")
            locationPermissionStatus = currentStatus
        }
        
        switch currentStatus {
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
        
        // Check if moving (based on last known location speed and recent movement)
        if let location = currentLocation {
            let isMoving = location.speed > 0.5 // Lower threshold for movement detection (was 1.0)
            let isRecentlyMoving = isRecentlyInMotion()
            
            if isMoving || isRecentlyMoving {
                print("🚶 Child moving (speed: \(location.speed)m/s, recent: \(isRecentlyMoving)) - using \(periodicUpdateIntervalMoving)s interval")
                return periodicUpdateIntervalMoving
            } else {
                print("🛑 Child stationary (speed: \(location.speed)m/s) - using \(periodicUpdateIntervalStationary)s interval")
                return periodicUpdateIntervalStationary
            }
        } else {
            print("🛑 No location data - using \(periodicUpdateIntervalStationary)s interval")
            return periodicUpdateIntervalStationary
        }
    }
    
    /// Check if child has been in motion recently (within last 2 minutes)
    private func isRecentlyInMotion() -> Bool {
        guard let lastUpdate = lastFirestoreUpdateTime else { return false }
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        
        // If we've been updating frequently (within 2 minutes), consider it recent motion
        return timeSinceLastUpdate < 120
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
            print("📍 No current location, requesting fresh location and will save when received")
            // Request a fresh location update
            // Set a flag so the next location received will be saved immediately
            Task { @MainActor in
                self.shouldSaveNextLocation = true
            }
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
    
    /// Set up real-time listener for geofence changes
    private func setupGeofenceListener() async {
        // Prevent duplicate listeners
        if geofenceListener != nil {
            print("⚠️ Geofence listener already active - skipping duplicate setup")
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for geofence listener")
            return
        }
        
        do {
            // Get user's familyId
            let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
            guard let familyId = userDoc.data()?["familyId"] as? String else {
                print("📍 No family ID for user - skipping geofence listener setup")
                return
            }
            
            print("📍 Setting up real-time geofence listener for family \(familyId)")
            
            // Set up Firestore snapshot listener
            let listener = Firestore.firestore().collection("geofences")
                .whereField("familyId", isEqualTo: familyId)
                .whereField("isActive", isEqualTo: true)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ Geofence listener error: \(error)")
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        print("❌ No snapshot in geofence listener")
                        return
                    }
                    
                    // Parse geofences from snapshot
                    let geofences = snapshot.documents.compactMap { doc -> Geofence? in
                        try? doc.data(as: Geofence.self)
                    }
                    
                    Task { @MainActor in
                        let oldCount = self.cachedGeofences.count
                        self.cachedGeofences = geofences
                        let newCount = geofences.count
                        
                        if newCount != oldCount {
                            print("📍 ✨ Geofences updated via real-time listener: \(oldCount) → \(newCount)")
                        } else {
                            print("📍 Geofences refreshed via real-time listener: \(newCount) geofences")
                        }
                        
                        // Log the names of current geofences
                        for geofence in geofences {
                            print("📍   - \(geofence.name) (\(Int(geofence.radius))m)")
                        }
                        
                        // Immediately check if current location is inside any new geofences
                        if let currentLocation = self.currentLocation {
                            print("📍 Checking current location against updated geofences...")
                            await self.checkGeofenceContainment(location: currentLocation)
                        } else {
                            print("📍 No current location available for immediate geofence check")
                        }
                    }
                }
            
            await MainActor.run {
                self.geofenceListener = listener
                print("✅ Real-time geofence listener active")
            }
            
        } catch {
            print("❌ Error setting up geofence listener: \(error)")
        }
    }
    
    /// Check if current location is inside any geofences and log events if state changed
    private func checkGeofenceContainment(location: CLLocation) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("📍 Checking containment - Last known geofence: \(lastKnownGeofenceId ?? "none")")
        
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
            print("📍 ⚡ State changed: \(lastKnownGeofenceId ?? "none") → \(currentGeofenceId ?? "none")")
            
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
        } else {
            print("📍 No state change - already in \(currentGeofenceId ?? "no geofence")")
        }
    }
    
    /// Log a synthetic geofence event (triggered by location check, not iOS boundary crossing)
    private func logSyntheticGeofenceEvent(geofence: Geofence, eventType: GeofenceEventType, location: CLLocation) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Get user's name
            let userDoc = try await Firestore.firestore().collection("users").document(userId).getDocument()
            let userName = userDoc.data()?["name"] as? String ?? "Unknown"
            
            // Geocode the location to get a readable address
            let geocoder = CLGeocoder()
            var addressString = "Unknown location"
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
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
                    if let country = placemark.country {
                        addressComponents.append(country)
                    }
                    
                    if !addressComponents.isEmpty {
                        addressString = addressComponents.joined(separator: " ")
                    }
                }
            } catch {
                print("📍 Geocoding failed: \(error.localizedDescription)")
                // Keep default "Unknown location" if geocoding fails
            }
            
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
                    "address": addressString, // Now includes geocoded address
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
            print("📍 When in use permission granted")
            print("📍 Starting background location to trigger Always permission upgrade prompt")
            
            // CRITICAL: Must actually USE background location to trigger iOS upgrade prompt
            // Enable background updates - this tells iOS we want to use background location
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            
            // Start location services - this demonstrates actual background usage
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            
            // Request a location update to prove we're using background capability
            locationManager.requestLocation()
            
            // After a short delay, request the upgrade
            // iOS will show "Change to Always Allow?" because we're actively using background location
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("📍 Requesting Always authorization upgrade...")
                self?.locationManager.requestAlwaysAuthorization()
            }
            
            print("✅ Background location started - iOS should show upgrade prompt when app goes to background")
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