import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Family Data Models

/// Represents a family in the system
struct Family: Codable, Identifiable {
    let id: String
    let name: String
    let createdBy: String // Parent user ID who created the family
    let createdAt: Date
    let members: [String: FamilyMember] // Map of userId -> FamilyMember
    
    enum CodingKeys: String, CodingKey {
        case id, name, createdBy, createdAt, members
    }
}

/// Represents a member within a family
struct FamilyMember: Codable, Equatable {
    let role: FamilyRole
    let name: String
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case role, name, joinedAt
    }
}

/// Roles within a family
enum FamilyRole: String, Codable, CaseIterable, Equatable {
    case parent = "parent"
    case child = "child"
    
    var displayName: String {
        switch self {
        case .parent: return "Parent"
        case .child: return "Child"
        }
    }
}

/// Represents an invitation to join a family
struct FamilyInvitation: Codable, Identifiable {
    let id: String // This is the invite code
    let familyId: String
    let createdBy: String // Parent user ID
    let childName: String
    let createdAt: Date
    let expiresAt: Date
    let usedBy: String? // Child user ID who used the invitation
    let usedAt: Date? // When the invitation was used
    
    enum CodingKeys: String, CodingKey {
        case id, familyId, createdBy, childName, createdAt, expiresAt, usedBy, usedAt
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var isUsed: Bool {
        usedBy != nil
    }
    
    var isValid: Bool {
        !isExpired && !isUsed
    }
}

// MARK: - Family Service

/// Service for managing family-related operations
@MainActor
class FamilyService: ObservableObject {
    @Published var currentFamily: Family?
    @Published var familyMembers: [String: FamilyMember] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var userListener: ListenerRegistration?
    private var familyListener: ListenerRegistration?
    
    init() {
        // Don't start listening immediately - wait for user authentication
        print("🔍 FamilyService initialized")
    }
    
    /// Handle authentication state changes
    func handleAuthStateChange(isAuthenticated: Bool, userId: String?) {
        if isAuthenticated, let userId = userId {
            print("🔍 User authenticated, starting family listener for: \(userId)")
            print("🔍 Current family before restart: \(currentFamily?.name ?? "nil")")
            
            // Force stop existing listeners before starting new ones
            userListener?.remove()
            familyListener?.remove()
            
            // Small delay to ensure listeners are fully stopped
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.listenToFamily(userId: userId)
            }
        } else {
            print("🔍 User not authenticated, stopping family listener")
            userListener?.remove()
            familyListener?.remove()
            currentFamily = nil
            familyMembers = [:]
        }
    }
    
    /// Force refresh the family listener by re-fetching the user's familyId
    func forceRefreshFamilyListener() async {
        guard let userId = auth.currentUser?.uid else {
            print("❌ Cannot force refresh: no authenticated user")
            return
        }
        
        print("🔄 Force refreshing family listener for user: \(userId)")
        
        // Try multiple times with increasing delays to handle timing issues
        for attempt in 1...3 {
            do {
                print("🔄 Attempt \(attempt): Checking user document for familyId")
                
                // Re-fetch the user document to get the latest familyId
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let data = userDoc.data(),
                   let familyId = data["familyId"] as? String {
                    print("🔍 Found updated familyId: \(familyId)")
                    
                    // Stop existing listeners
                    userListener?.remove()
                    familyListener?.remove()
                    
                    // Start fresh listener with the updated familyId
                    listenToFamily(userId: userId)
                    return
                } else {
                    print("ℹ️ Attempt \(attempt): No familyId found in user document")
                    if attempt < 3 {
                        print("🔄 Waiting 1 second before retry...")
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            } catch {
                print("❌ Attempt \(attempt): Error force refreshing family listener: \(error)")
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        
        print("ℹ️ No familyId found after 3 attempts, restarting listener anyway")
        // Still restart the listener to clear any stale state
        listenToFamily(userId: userId)
    }
    
    /// Remove a child from the family
    func removeChildFromFamily(childId: String, familyId: String) async throws {
        print("🔍 Removing child \(childId) from family \(familyId)")
        
        // Remove child from family members
        try await db.collection("families").document(familyId).updateData([
            "members.\(childId)": FieldValue.delete()
        ])
        
        // Remove familyId from child's user document
        try await db.collection("users").document(childId).updateData([
            "familyId": FieldValue.delete()
        ])
        
        print("✅ Successfully removed child from family")
    }
    
    // MARK: - Family Management
    
    /// Create a new family using Cloud Function via HTTP
    func createFamily(name: String) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw FamilyError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get the parent's name from the current user
            let parentName = auth.currentUser?.displayName ?? "Parent"
            
            print("🔍 Creating family using Cloud Function: \(name)")
            
            // Get Firebase ID token for authentication
            guard let idToken = try await auth.currentUser?.getIDToken() else {
                throw FamilyError.notAuthenticated
            }
            
            // Call the createFamily Cloud Function via HTTP
            let url = URL(string: "https://us-central1-located-d9dce.cloudfunctions.net/createFamily")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            
            let requestBody = [
                "data": [
                    "familyName": name,
                    "parentName": parentName
                ]
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw FamilyError.familyNotFound
            }
            
            // Parse the response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let familyId = result["familyId"] as? String else {
                throw FamilyError.familyNotFound
            }
            
            print("✅ Family created successfully with ID: \(familyId)")
            
            // Update user's familyId
            try await db.collection("users").document(userId).updateData([
                "familyId": familyId
            ])
            print("✅ Updated user's familyId to: \(familyId)")
            
            // Restart listening to pick up the new family
            restartListening()
            
            // The family data will be loaded automatically by the listener
            await MainActor.run {
                self.isLoading = false
            }
            
            print("✅ Family '\(name)' created successfully with ID: \(familyId)")
            return familyId
            
        } catch {
            print("❌ Error creating family: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw error
        }
    }
    
    /// Join an existing family
    func joinFamily(familyId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw FamilyError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get family document
            let familyDoc = try await db.collection("families").document(familyId).getDocument()
            
            guard let familyData = familyDoc.data() else {
                throw FamilyError.familyNotFound
            }
            
            // Update user's familyId
            try await db.collection("users").document(userId).updateData([
                "familyId": familyId
            ])
            
            // The actual family membership will be handled by the acceptInvitation Cloud Function
            isLoading = false
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Restart listening for family changes (useful after user authentication or family creation)
    func restartListening() {
        if let userId = auth.currentUser?.uid {
            print("🔄 Restarting family listener for user: \(userId)")
            listenToFamily(userId: userId)
        }
    }
    
    /// Listen to family changes
    private func listenToFamily(userId: String) {
        // Stop existing listeners
        userListener?.remove()
        familyListener?.remove()
        
        print("🔍 Starting to listen for family changes for user: \(userId)")
        
        // First get the user's familyId
        userListener = db.collection("users").document(userId).addSnapshotListener { [weak self] documentSnapshot, error in
            if let error = error {
                print("❌ Error listening to user document: \(error)")
                return
            }
            
            guard let document = documentSnapshot,
                  let data = document.data(),
                  let familyId = data["familyId"] as? String else {
                print("ℹ️ User has no familyId - document exists: \(documentSnapshot?.exists ?? false)")
                if let data = documentSnapshot?.data() {
                    print("ℹ️ User document data: \(data)")
                }
                self?.familyListener?.remove()
                self?.currentFamily = nil
                self?.familyMembers = [:]
                return
            }
            
            print("🔍 User has familyId: \(familyId)")
            
            // Stop old family listener
            self?.familyListener?.remove()
            
            // Listen to family document
            self?.familyListener = self?.db.collection("families").document(familyId).addSnapshotListener { familySnapshot, familyError in
                if let familyError = familyError {
                    print("❌ Error listening to family document: \(familyError)")
                    return
                }
                
                guard let familyData = familySnapshot?.data() else {
                    print("ℹ️ Family document not found")
                    return
                }
                
                do {
                    // Add the familyId as the id field for decoding
                    var familyDataWithId = familyData
                    familyDataWithId["id"] = familyId
                    
                    let family = try Firestore.Decoder().decode(Family.self, from: familyDataWithId)
                    print("✅ Successfully loaded family: \(family.name) with \(family.members.count) members")
                    self?.currentFamily = family
                    self?.familyMembers = family.members
                } catch {
                    print("❌ Error decoding family: \(error)")
                }
            }
        }
    }
    
    /// Get family members as an array
    func getFamilyMembers() -> [(String, FamilyMember)] {
        return Array(familyMembers)
    }
    
    /// Get children in the family
    func getChildren() -> [(String, FamilyMember)] {
        return familyMembers.filter { $0.value.role == .child }
    }
    
    /// Get parents in the family
    func getParents() -> [(String, FamilyMember)] {
        return familyMembers.filter { $0.value.role == .parent }
    }
    
    /// Clean up listeners
    deinit {
        userListener?.remove()
        familyListener?.remove()
        print("🛑 FamilyService deallocated")
    }
}

// MARK: - Family Errors

enum FamilyError: LocalizedError {
    case notAuthenticated
    case familyNotFound
    case invalidInvitation
    case invitationExpired
    case invitationAlreadyUsed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .familyNotFound:
            return "Family not found"
        case .invalidInvitation:
            return "Invalid invitation code"
        case .invitationExpired:
            return "Invitation has expired"
        case .invitationAlreadyUsed:
            return "Invitation has already been used"
        }
    }
}
