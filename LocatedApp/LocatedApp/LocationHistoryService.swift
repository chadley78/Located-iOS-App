import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Location History Point Model
struct LocationHistoryPoint: Identifiable, Codable {
    let id: String
    let childId: String
    let familyId: String
    let lat: Double
    let lng: Double
    let accuracy: Double
    let timestamp: Date
    let address: String?
    let batteryLevel: Int?
    let isMoving: Bool
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, childId, familyId, lat, lng, accuracy, timestamp, address, batteryLevel, isMoving
    }
}

// MARK: - Location History Service
@MainActor
class LocationHistoryService: ObservableObject {
    @Published var historyPoints: [LocationHistoryPoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    /// Fetch location history for a child within the specified number of hours
    func fetchHistory(childId: String, hours: Int = 6) async {
        print("📍 Fetching location history for child: \(childId), last \(hours) hours")
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Calculate cutoff time
            let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)
            let cutoffTimestamp = Timestamp(date: cutoffDate)
            
            // Query location history
            let snapshot = try await db.collection("location_history")
                .whereField("childId", isEqualTo: childId)
                .whereField("timestamp", isGreaterThan: cutoffTimestamp)
                .order(by: "timestamp", descending: false)
                .getDocuments()
            
            print("📍 Found \(snapshot.documents.count) history points")
            
            // Parse documents
            let points = snapshot.documents.compactMap { doc -> LocationHistoryPoint? in
                var data = doc.data()
                data["id"] = doc.documentID
                
                // Handle Firestore Timestamp
                if let timestamp = data["timestamp"] as? Timestamp {
                    data["timestamp"] = timestamp.dateValue()
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(LocationHistoryPoint.self, from: jsonData)
                } catch {
                    print("❌ Error decoding history point: \(error)")
                    return nil
                }
            }
            
            self.historyPoints = points
            self.isLoading = false
            
            print("✅ Successfully loaded \(points.count) history points")
            
        } catch {
            print("❌ Error fetching location history: \(error)")
            self.errorMessage = "Failed to load location history: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    /// Clear cached history points
    func clearHistory() {
        historyPoints = []
    }
}

