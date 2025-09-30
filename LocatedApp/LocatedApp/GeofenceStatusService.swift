import Foundation
import FirebaseFirestore
import Combine

// MARK: - Geofence Status Model
struct GeofenceStatus: Identifiable, Equatable {
    let id: String
    let childId: String
    let childName: String
    let lastEvent: GeofenceEventType
    let geofenceName: String
    let timestamp: Date
    
    var displayText: String {
        let timeString = timestamp.formatted(date: .omitted, time: .shortened)
        return "\(lastEvent.displayName) \"\(geofenceName)\" at \(timeString)"
    }
}

// MARK: - Geofence Status Service
@MainActor
class GeofenceStatusService: ObservableObject {
    @Published var childGeofenceStatus: [String: GeofenceStatus] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        listener?.remove()
        print("🛑 GeofenceStatusService deallocated")
    }
    
    // MARK: - Public Methods
    
    /// Start listening to geofence events for a family
    func listenToGeofenceEvents(familyId: String) {
        print("🔍 GeofenceStatusService - Starting to listen for family: \(familyId)")
        
        // Remove existing listener
        listener?.remove()
        
        isLoading = true
        errorMessage = nil
        
        // First, load existing geofence events
        Task {
            await loadLatestGeofenceEvents(familyId: familyId)
            
            // Then start the real-time listener
            await MainActor.run {
                self.startRealtimeListener(familyId: familyId)
            }
        }
    }
    
    /// Load the latest geofence event for each child in the family
    private func loadLatestGeofenceEvents(familyId: String) async {
        print("🔍 GeofenceStatusService - Loading latest geofence events for family: \(familyId)")
        
        do {
            // Query for all geofence events for this family, ordered by timestamp descending
            let snapshot = try await db.collection("geofence_events")
                .whereField("familyId", isEqualTo: familyId)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            print("🔍 GeofenceStatusService - Found \(snapshot.documents.count) geofence events")
            
            // Group events by childId and keep only the latest event per child
            var latestEventsByChild: [String: [String: Any]] = [:]
            
            for document in snapshot.documents {
                let data = document.data()
                guard let childId = data["childId"] as? String else { continue }
                
                // Keep only the first (latest) event for each child
                if latestEventsByChild[childId] == nil {
                    latestEventsByChild[childId] = data
                    print("🔍 GeofenceStatusService - Latest event for child \(childId): \(data)")
                }
            }
            
            // Process the latest events
            await MainActor.run {
                for (childId, eventData) in latestEventsByChild {
                    processGeofenceEvent(eventData)
                }
                print("🔍 GeofenceStatusService - Loaded \(latestEventsByChild.count) latest geofence events")
            }
            
        } catch {
            print("❌ GeofenceStatusService - Error loading latest geofence events: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load geofence events: \(error.localizedDescription)"
            }
        }
    }
    
    /// Start the real-time listener for new geofence events
    private func startRealtimeListener(familyId: String) {
        print("🔍 GeofenceStatusService - Starting real-time listener for family: \(familyId)")
        
        listener = db.collection("geofence_events")
            .whereField("familyId", isEqualTo: familyId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ GeofenceStatusService - Error listening to geofence events: \(error)")
                        self.errorMessage = "Failed to load geofence events: \(error.localizedDescription)"
                        self.isLoading = false
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        print("🔍 GeofenceStatusService - No snapshot received")
                        self.isLoading = false
                        return
                    }
                    
                    print("🔍 GeofenceStatusService - Received \(snapshot.documentChanges.count) geofence event changes")
                    print("🔍 GeofenceStatusService - Total documents in snapshot: \(snapshot.documents.count)")
                    
                    // Debug: Print all document IDs in the snapshot
                    for doc in snapshot.documents {
                        print("🔍 GeofenceStatusService - Document ID: \(doc.documentID), data: \(doc.data())")
                    }
                    
                    // Process document changes (only new events since we already loaded existing ones)
                    for change in snapshot.documentChanges {
                        switch change.type {
                        case .added:
                            // Only process newly added events (not existing ones we already loaded)
                            if let eventData = change.document.data() as? [String: Any] {
                                print("🔍 GeofenceStatusService - New geofence event added: \(eventData)")
                                self.processGeofenceEvent(eventData)
                            }
                        case .modified:
                            // Handle modified events if needed
                            if let eventData = change.document.data() as? [String: Any] {
                                print("🔍 GeofenceStatusService - Geofence event modified: \(eventData)")
                                self.processGeofenceEvent(eventData)
                            }
                        case .removed:
                            // Handle removed events if needed
                            break
                        }
                    }
                    
                    self.isLoading = false
                }
            }
    }
    
    /// Stop listening to geofence events
    func stopListening() {
        print("🔍 GeofenceStatusService - Stopping listener")
        listener?.remove()
        listener = nil
        childGeofenceStatus.removeAll()
    }
    
    /// Get the latest geofence status for a specific child
    func getStatusForChild(childId: String) -> GeofenceStatus? {
        return childGeofenceStatus[childId]
    }
    
    // MARK: - Private Methods
    
    private func processGeofenceEvent(_ eventData: [String: Any]) {
        print("🔍 GeofenceStatusService - Processing event data: \(eventData)")
        
        guard let childId = eventData["childId"] as? String,
              let childName = eventData["childName"] as? String,
              let geofenceName = eventData["geofenceName"] as? String,
              let eventTypeString = eventData["eventType"] as? String,
              let timestamp = eventData["timestamp"] as? Timestamp else {
            print("❌ GeofenceStatusService - Invalid event data: \(eventData)")
            return
        }
        
        print("🔍 GeofenceStatusService - Parsed event: childId=\(childId), childName=\(childName), geofenceName=\(geofenceName), eventType=\(eventTypeString)")
        
        // Parse event type
        let eventType: GeofenceEventType
        switch eventTypeString {
        case "enter":
            eventType = .enter
        case "exit":
            eventType = .exit
        default:
            print("❌ GeofenceStatusService - Unknown event type: \(eventTypeString)")
            return
        }
        
        // Create geofence status
        let status = GeofenceStatus(
            id: "\(childId)_\(geofenceName)_\(timestamp.seconds)",
            childId: childId,
            childName: childName,
            lastEvent: eventType,
            geofenceName: geofenceName,
            timestamp: timestamp.dateValue()
        )
        
        // Update the status for this child (keep only the most recent event)
        childGeofenceStatus[childId] = status
        
        print("🔍 GeofenceStatusService - Updated status for \(childName): \(status.displayText)")
        print("🔍 GeofenceStatusService - Current statuses: \(childGeofenceStatus.keys)")
    }
    
    /// Clear all geofence status data
    func clearStatus() {
        childGeofenceStatus.removeAll()
        print("🔍 GeofenceStatusService - Cleared all status data")
    }
}
