import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import MapKit

// MARK: - Geofence Data Models
struct Geofence: Codable, Identifiable {
    let id: String
    let familyId: String // Reference to the family
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double // in meters
    let isActive: Bool
    let createdAt: Date
    let createdBy: String // parent user ID
    let notifyOnEnter: Bool // Send notification when child enters
    let notifyOnExit: Bool // Send notification when child exits
    
    enum CodingKeys: String, CodingKey {
        case id, familyId, name, latitude, longitude, radius, isActive, createdAt, createdBy, notifyOnEnter, notifyOnExit
    }
    
    // Custom initializer for backward compatibility with existing geofences
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        familyId = try container.decode(String.self, forKey: .familyId)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        radius = try container.decode(Double.self, forKey: .radius)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        // Default to true for backward compatibility
        notifyOnEnter = try container.decodeIfPresent(Bool.self, forKey: .notifyOnEnter) ?? true
        notifyOnExit = try container.decodeIfPresent(Bool.self, forKey: .notifyOnExit) ?? true
    }
    
    // Standard initializer
    init(id: String, familyId: String, name: String, latitude: Double, longitude: Double, radius: Double, isActive: Bool, createdAt: Date, createdBy: String, notifyOnEnter: Bool = true, notifyOnExit: Bool = true) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.isActive = isActive
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.notifyOnEnter = notifyOnEnter
        self.notifyOnExit = notifyOnExit
    }
}

struct GeofenceEvent: Codable, Identifiable {
    let id: String
    let familyId: String // Reference to the family
    let childId: String
    let childName: String
    let geofenceId: String
    let geofenceName: String
    let eventType: GeofenceEventType
    let timestamp: Date
    let location: LocationData
    
    enum CodingKeys: String, CodingKey {
        case id, familyId, childId, childName, geofenceId, geofenceName, eventType, timestamp, location
    }
}

enum GeofenceEventType: String, Codable, CaseIterable {
    case enter = "enter"
    case exit = "exit"
    
    var displayName: String {
        switch self {
        case .enter: return "Entered"
        case .exit: return "Left"
        }
    }
}

// MARK: - Geofence Service
@MainActor
class GeofenceService: NSObject, ObservableObject {
    @Published var geofences: [Geofence] = []
    @Published var geofenceEvents: [GeofenceEvent] = [] // Add this line back
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    var authenticationService: AuthenticationService?
    
    private let db = Firestore.firestore()
    private let locationManager = CLLocationManager()
    
    // Monitored regions for Core Location
    private var monitoredRegions: [String: CLCircularRegion] = [:]
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Geofence Management
    
    /// Create a new geofence for a child
    func createGeofence(
        familyId: String,
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        notifyOnEnter: Bool = true,
        notifyOnExit: Bool = true
    ) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GeofenceError.notAuthenticated
        }
        
        print("🔍 Creating geofence for familyId: \(familyId), by user: \(currentUser.uid)")
        
        // Check if the user has a familyId in their user document
        let userDoc = try await Firestore.firestore().collection("users").document(currentUser.uid).getDocument()
        guard let userData = userDoc.data(),
              let userFamilyId = userData["familyId"] as? String else {
            print("❌ User has no familyId - cannot create geofence")
            throw GeofenceError.notFamilyMember
        }
        
        // Verify the user is trying to create a geofence for their own family
        guard userFamilyId == familyId else {
            print("❌ User trying to create geofence for different family")
            throw GeofenceError.notFamilyMember
        }
        
        print("✅ User is member of family: \(familyId)")
        
        // Additional debugging: Check if family document exists and is accessible
        do {
            let familyDoc = try await Firestore.firestore().collection("families").document(familyId).getDocument()
            if familyDoc.exists {
                print("✅ Family document exists and is accessible")
                if let familyData = familyDoc.data() {
                    print("🔍 Family data: \(familyData)")
                }
            } else {
                print("❌ Family document does not exist: \(familyId)")
            }
        } catch {
            print("❌ Error accessing family document: \(error)")
        }
        
        let geofence = Geofence(
            id: UUID().uuidString,
            familyId: familyId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            isActive: true,
            createdAt: Date(),
            createdBy: currentUser.uid,
            notifyOnEnter: notifyOnEnter,
            notifyOnExit: notifyOnExit
        )
        
        let geofenceData: [String: Any] = [
            "id": geofence.id,
            "familyId": geofence.familyId,
            "name": geofence.name,
            "latitude": geofence.latitude,
            "longitude": geofence.longitude,
            "radius": geofence.radius,
            "isActive": geofence.isActive,
            "createdAt": geofence.createdAt,
            "createdBy": geofence.createdBy,
            "notifyOnEnter": geofence.notifyOnEnter,
            "notifyOnExit": geofence.notifyOnExit
        ]
        
        print("🔍 Geofence data: \(geofenceData)")
        
        do {
            try await db.collection("geofences").document(geofence.id).setData(geofenceData)
            print("✅ Geofence created successfully")
        } catch {
            print("❌ Failed to create geofence: \(error)")
            throw error
        }
        
        // Add to local array
        await MainActor.run {
            geofences.append(geofence)
        }
    }
    
    /// Fetch geofences for a specific family
    func fetchGeofences(for familyId: String) async {
        print("🔍 Fetching geofences for familyId: \(familyId)")
        isLoading = true
        errorMessage = nil
        
        do {
            let snapshot = try await db.collection("geofences")
                .whereField("familyId", isEqualTo: familyId)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            print("📊 Found \(snapshot.documents.count) geofence documents")
            
            let fetchedGeofences = snapshot.documents.compactMap { doc in
                try? doc.data(as: Geofence.self)
            }
            
            print("✅ Successfully parsed \(fetchedGeofences.count) geofences")
            for geofence in fetchedGeofences {
                print("📍 Geofence: \(geofence.name) at \(geofence.latitude), \(geofence.longitude) with radius \(geofence.radius)m")
            }
            
            await MainActor.run {
                self.geofences = fetchedGeofences
                self.isLoading = false
            }
            
        } catch {
            print("❌ Failed to fetch geofences: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to fetch geofences: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Update an existing geofence
    func updateGeofence(
        geofence: Geofence,
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        notifyOnEnter: Bool,
        notifyOnExit: Bool
    ) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GeofenceError.notAuthenticated
        }
        
        print("🔍 Updating geofence \(geofence.id) for familyId: \(geofence.familyId), by user: \(currentUser.uid)")
        
        // Check if the user has a familyId in their user document
        let userDoc = try await Firestore.firestore().collection("users").document(currentUser.uid).getDocument()
        guard let userData = userDoc.data(),
              let userFamilyId = userData["familyId"] as? String else {
            print("❌ User has no familyId - cannot update geofence")
            throw GeofenceError.notFamilyMember
        }
        
        // Verify the user is trying to update a geofence for their own family
        guard userFamilyId == geofence.familyId else {
            print("❌ User trying to update geofence for different family")
            throw GeofenceError.notFamilyMember
        }
        
        print("✅ User is member of family: \(geofence.familyId)")
        
        // Update the geofence document
        try await db.collection("geofences").document(geofence.id).updateData([
            "name": name,
            "latitude": latitude,
            "longitude": longitude,
            "radius": radius,
            "notifyOnEnter": notifyOnEnter,
            "notifyOnExit": notifyOnExit,
            "updatedAt": Timestamp()
        ])
        
        print("✅ Geofence updated successfully: \(geofence.id)")
        
        // Refresh the local geofences list
        await fetchGeofences(for: geofence.familyId)
    }
    
    /// Delete a geofence
    func deleteGeofence(_ geofence: Geofence) async throws {
        try await db.collection("geofences").document(geofence.id).updateData([
            "isActive": false
        ])
        
        await MainActor.run {
            geofences.removeAll { $0.id == geofence.id }
        }
        
        // Stop monitoring the region
        stopMonitoringGeofence(geofence)
    }
    
    /// Update notification settings for a geofence
    func updateNotificationSettings(
        geofenceId: String,
        notifyOnEnter: Bool,
        notifyOnExit: Bool
    ) async throws {
        try await db.collection("geofences").document(geofenceId).updateData([
            "notifyOnEnter": notifyOnEnter,
            "notifyOnExit": notifyOnExit
        ])
        
        print("✅ Notification settings updated for geofence: \(geofenceId)")
        print("   Enter notifications: \(notifyOnEnter ? "ON" : "OFF")")
        print("   Exit notifications: \(notifyOnExit ? "ON" : "OFF")")
        
        // Update local geofences array
        await MainActor.run {
            if let index = geofences.firstIndex(where: { $0.id == geofenceId }) {
                let oldGeofence = geofences[index]
                let updatedGeofence = Geofence(
                    id: oldGeofence.id,
                    familyId: oldGeofence.familyId,
                    name: oldGeofence.name,
                    latitude: oldGeofence.latitude,
                    longitude: oldGeofence.longitude,
                    radius: oldGeofence.radius,
                    isActive: oldGeofence.isActive,
                    createdAt: oldGeofence.createdAt,
                    createdBy: oldGeofence.createdBy,
                    notifyOnEnter: notifyOnEnter,
                    notifyOnExit: notifyOnExit
                )
                geofences[index] = updatedGeofence
            }
        }
    }
    
    // MARK: - Geofence Monitoring
    
    /// Start monitoring all geofences for a family
    func startMonitoringGeofences(for familyId: String) {
        print("🔍 Starting geofence monitoring for familyId: \(familyId)")
        let familyGeofences = geofences.filter { $0.familyId == familyId }
        
        print("📊 Found \(familyGeofences.count) geofences to monitor")
        
        for geofence in familyGeofences {
            startMonitoringGeofence(geofence)
        }
        
        if familyGeofences.isEmpty {
            print("⚠️ No geofences found to monitor for familyId: \(familyId)")
        }
    }
    
    /// Start monitoring a specific geofence
    private func startMonitoringGeofence(_ geofence: Geofence) {
        print("🔍 Setting up monitoring for geofence: \(geofence.name)")
        print("📍 Location: \(geofence.latitude), \(geofence.longitude)")
        print("📏 Radius: \(geofence.radius)m")
        
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: geofence.latitude,
                longitude: geofence.longitude
            ),
            radius: geofence.radius,
            identifier: geofence.id
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        // Check if location services are available
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services are not enabled")
            return
        }
        
        // Check authorization status
        let authStatus = locationManager.authorizationStatus
        print("🔐 Location authorization status: \(authStatus.rawValue)")
        
        if authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse {
            locationManager.startMonitoring(for: region)
            monitoredRegions[geofence.id] = region
            print("✅ Started monitoring geofence: \(geofence.name)")
        } else {
            print("❌ Location authorization not sufficient for geofence monitoring")
        }
    }
    
    /// Stop monitoring a specific geofence
    private func stopMonitoringGeofence(_ geofence: Geofence) {
        if let region = monitoredRegions[geofence.id] {
            locationManager.stopMonitoring(for: region)
            monitoredRegions.removeValue(forKey: geofence.id)
            print("📍 Stopped monitoring geofence: \(geofence.name)")
        }
    }
    
    /// Stop monitoring all geofences
    func stopMonitoringAllGeofences() {
        for region in monitoredRegions.values {
            locationManager.stopMonitoring(for: region)
        }
        monitoredRegions.removeAll()
        print("📍 Stopped monitoring all geofences")
    }
    
    // MARK: - Geofence Events
    
    /// Log a geofence event to Firestore
    private func logGeofenceEvent(
        geofence: Geofence,
        eventType: GeofenceEventType,
        location: CLLocation
    ) async {
        do {
            // For family-centric approach, we need to get the current user's info
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("❌ No authenticated user for geofence event")
                return
            }
            
            let event = GeofenceEvent(
                id: UUID().uuidString,
                familyId: geofence.familyId,
                childId: currentUserId,
                childName: "Current User", // This should be updated to get actual name
                geofenceId: geofence.id,
                geofenceName: geofence.name,
                eventType: eventType,
                timestamp: Date(),
                location: LocationData(
                    familyId: geofence.familyId,
                    lat: location.coordinate.latitude,
                    lng: location.coordinate.longitude,
                    accuracy: location.horizontalAccuracy,
                    timestamp: Date(),
                    address: nil,
                    batteryLevel: nil,
                    isMoving: location.speed > 1.0
                )
            )
            
            try await db.collection("geofence_events").document(event.id).setData([
                "id": event.id,
                "familyId": event.familyId,
                "childId": event.childId,
                "childName": event.childName,
                "geofenceId": event.geofenceId,
                "geofenceName": event.geofenceName,
                "eventType": event.eventType.rawValue,
                "timestamp": event.timestamp,
                "location": [
                    "lat": event.location.lat,
                    "lng": event.location.lng,
                    "timestamp": event.location.timestamp,
                    "accuracy": event.location.accuracy,
                    "address": event.location.address as Any,
                    "batteryLevel": event.location.batteryLevel as Any,
                    "isMoving": event.location.isMoving,
                    "lastUpdated": event.location.lastUpdated
                ]
            ])
            
            print("📍 Logged geofence event: \(eventType.displayName) \(geofence.name)")
            
        } catch {
            print("❌ Failed to log geofence event: \(error.localizedDescription)")
        }
    }
    
    /// Fetch geofence events for a family
    func fetchGeofenceEvents(for familyId: String) async {
        do {
            let snapshot = try await db.collection("geofence_events")
                .whereField("familyId", isEqualTo: familyId)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let events = snapshot.documents.compactMap { doc in
                try? doc.data(as: GeofenceEvent.self)
            }
            
            await MainActor.run {
                self.geofenceEvents = events
            }
            
        } catch {
            print("❌ Failed to fetch geofence events: \(error.localizedDescription)")
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension GeofenceService: @preconcurrency CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        Task { @MainActor in
            guard let geofence = geofences.first(where: { $0.id == circularRegion.identifier }) else {
                return
            }
            
            await logGeofenceEvent(
                geofence: geofence,
                eventType: .enter,
                location: CLLocation(
                    latitude: circularRegion.center.latitude,
                    longitude: circularRegion.center.longitude
                )
            )
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        Task { @MainActor in
            guard let geofence = geofences.first(where: { $0.id == circularRegion.identifier }) else {
                return
            }
            
            await logGeofenceEvent(
                geofence: geofence,
                eventType: .exit,
                location: CLLocation(
                    latitude: circularRegion.center.latitude,
                    longitude: circularRegion.center.longitude
                )
            )
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("❌ Geofence monitoring failed: \(error.localizedDescription)")
    }
}

// MARK: - Errors
enum GeofenceError: LocalizedError {
    case notAuthenticated
    case invalidLocation
    case geofenceNotFound
    case notFamilyMember
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidLocation:
            return "Invalid location data"
        case .geofenceNotFound:
            return "Geofence not found"
        case .notFamilyMember:
            return "User is not a member of this family"
        }
    }
}
