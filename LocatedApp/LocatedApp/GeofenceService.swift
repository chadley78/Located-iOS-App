import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import MapKit

// MARK: - Geofence Data Models
struct Geofence: Codable, Identifiable {
    let id: String
    let childId: String
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double // in meters
    let isActive: Bool
    let createdAt: Date
    let createdBy: String // parent user ID
    
    enum CodingKeys: String, CodingKey {
        case id, childId, name, latitude, longitude, radius, isActive, createdAt, createdBy
    }
}

struct GeofenceEvent: Codable, Identifiable {
    let id: String
    let childId: String
    let childName: String
    let geofenceId: String
    let geofenceName: String
    let eventType: GeofenceEventType
    let timestamp: Date
    let location: LocationData
    
    enum CodingKeys: String, CodingKey {
        case id, childId, childName, geofenceId, geofenceName, eventType, timestamp, location
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
    private let db = Firestore.firestore()
    private let locationManager = CLLocationManager()
    
    @Published var geofences: [Geofence] = []
    @Published var geofenceEvents: [GeofenceEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
        childId: String,
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double
    ) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GeofenceError.notAuthenticated
        }
        
        print("🔍 Creating geofence for childId: \(childId), by user: \(currentUser.uid)")
        
        let geofence = Geofence(
            id: UUID().uuidString,
            childId: childId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            isActive: true,
            createdAt: Date(),
            createdBy: currentUser.uid
        )
        
        let geofenceData: [String: Any] = [
            "id": geofence.id,
            "childId": geofence.childId,
            "name": geofence.name,
            "latitude": geofence.latitude,
            "longitude": geofence.longitude,
            "radius": geofence.radius,
            "isActive": geofence.isActive,
            "createdAt": geofence.createdAt,
            "createdBy": geofence.createdBy
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
    
    /// Fetch geofences for a specific child
    func fetchGeofences(for childId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let snapshot = try await db.collection("geofences")
                .whereField("childId", isEqualTo: childId)
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            let fetchedGeofences = snapshot.documents.compactMap { doc in
                try? doc.data(as: Geofence.self)
            }
            
            await MainActor.run {
                self.geofences = fetchedGeofences
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch geofences: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
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
    
    // MARK: - Geofence Monitoring
    
    /// Start monitoring all geofences for a child
    func startMonitoringGeofences(for childId: String) {
        let childGeofences = geofences.filter { $0.childId == childId }
        
        for geofence in childGeofences {
            startMonitoringGeofence(geofence)
        }
    }
    
    /// Start monitoring a specific geofence
    private func startMonitoringGeofence(_ geofence: Geofence) {
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
        
        locationManager.startMonitoring(for: region)
        monitoredRegions[geofence.id] = region
        
        print("📍 Started monitoring geofence: \(geofence.name)")
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
            // Get child name
            let childDoc = try await db.collection("users").document(geofence.childId).getDocument()
            let childName = childDoc.data()?["name"] as? String ?? "Unknown Child"
            
            let event = GeofenceEvent(
                id: UUID().uuidString,
                childId: geofence.childId,
                childName: childName,
                geofenceId: geofence.id,
                geofenceName: geofence.name,
                eventType: eventType,
                timestamp: Date(),
                location: LocationData(
                    lat: location.coordinate.latitude,
                    lng: location.coordinate.longitude,
                    accuracy: location.horizontalAccuracy,
                    timestamp: Date(),
                    address: nil,
                    batteryLevel: nil,
                    isMoving: false
                )
            )
            
            try await db.collection("geofence_events").document(event.id).setData([
                "id": event.id,
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
    
    /// Fetch geofence events for a child
    func fetchGeofenceEvents(for childId: String) async {
        do {
            let snapshot = try await db.collection("geofence_events")
                .whereField("childId", isEqualTo: childId)
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
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidLocation:
            return "Invalid location data"
        case .geofenceNotFound:
            return "Geofence not found"
        }
    }
}
