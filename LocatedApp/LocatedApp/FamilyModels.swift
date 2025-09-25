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
    let imageURL: String?
    let imageBase64: String?
    let hasImage: Bool?
    
    init(role: FamilyRole, name: String, joinedAt: Date, imageURL: String? = nil, imageBase64: String? = nil, hasImage: Bool? = nil) {
        self.role = role
        self.name = name
        self.joinedAt = joinedAt
        self.imageURL = imageURL
        self.imageBase64 = imageBase64
        self.hasImage = hasImage
    }
    
    enum CodingKeys: String, CodingKey {
        case role, name, joinedAt, imageURL, imageBase64, hasImage
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

/// Represents a child in pending state (invitation sent but not accepted)
struct PendingFamilyChild: Codable, Identifiable {
    let id: String // Unique ID for the pending child
    let invitationCode: String // The invitation code
    let name: String
    let createdAt: Date
    let imageBase64: String? // Optional profile image
    let status: InvitationStatus
    
    enum CodingKeys: String, CodingKey {
        case id, invitationCode, name, createdAt, imageBase64, status
    }
}

/// Status of an invitation
enum InvitationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Invite not accepted"
        case .accepted: return "Accepted"
        case .cancelled: return "Cancelled"
        }
    }
}

/// Combined child display item for UI
struct ChildDisplayItem: Identifiable {
    let id: String
    let name: String
    let role: FamilyRole
    let joinedAt: Date
    let imageBase64: String?
    let status: InvitationStatus
    let isPending: Bool
    
    init(from familyMember: FamilyMember, id: String) {
        self.id = id
        self.name = familyMember.name
        self.role = familyMember.role
        self.joinedAt = familyMember.joinedAt
        self.imageBase64 = familyMember.imageBase64
        self.status = .accepted
        self.isPending = false
    }
    
    init(from pendingChild: PendingFamilyChild) {
        self.id = pendingChild.id
        self.name = pendingChild.name
        self.role = .child
        self.joinedAt = pendingChild.createdAt
        self.imageBase64 = pendingChild.imageBase64
        self.status = pendingChild.status
        self.isPending = true
    }
}

// MARK: - Family Service

/// Service for managing family-related operations
@MainActor
class FamilyService: ObservableObject {
    @Published var currentFamily: Family?
    @Published var familyMembers: [String: FamilyMember] = [:]
    @Published var pendingChildren: [PendingFamilyChild] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var userListener: ListenerRegistration?
    private var familyListener: ListenerRegistration?
    private var pendingChildrenListener: ListenerRegistration?
    
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
            pendingChildrenListener?.remove()
            
            // Small delay to ensure listeners are fully stopped
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.listenToFamily(userId: userId)
            }
        } else {
            print("🔍 User not authenticated, stopping family listener")
            userListener?.remove()
            familyListener?.remove()
            pendingChildrenListener?.remove()
            currentFamily = nil
            familyMembers = [:]
            pendingChildren = []
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
    
    /// Update a family member's name
    func updateFamilyMemberName(childId: String, familyId: String, newName: String) async throws {
        print("🔍 Updating family member \(childId) name to '\(newName)' in family \(familyId)")
        
        // Update the member's name in the family document
        try await db.collection("families").document(familyId).updateData([
            "members.\(childId).name": newName
        ])
        
        // Force refresh of family data to ensure UI updates immediately
        await refreshFamilyData(familyId: familyId)
        
        print("✅ Successfully updated family member name")
    }
    
    /// Update a child's profile image URL
    func updateChildImageURL(childId: String, familyId: String, imageURL: String) async throws {
        print("🔍 Updating child \(childId) image URL in family \(familyId)")
        
        // Update the child's image URL in the family document
        try await db.collection("families").document(familyId).updateData([
            "members.\(childId).imageURL": imageURL
        ])
        
        // Force refresh of family data to ensure UI updates immediately
        await refreshFamilyData(familyId: familyId)
        
        print("✅ Successfully updated child image URL")
    }
    
    /// Update a child's profile image as base64 string
    func updateChildImageBase64(childId: String, familyId: String, imageBase64: String) async throws {
        print("🔍 FamilyService: Updating child \(childId) image base64 in family \(familyId)")
        print("🔍 FamilyService: Base64 length: \(imageBase64.count)")
        
        // Store the compressed image directly in the family document (now small enough)
        try await db.collection("families").document(familyId).updateData([
            "members.\(childId).imageBase64": imageBase64
        ])
        
        print("🔍 FamilyService: Successfully updated Firestore document")
        
        // Force refresh of family data to ensure UI updates immediately
        await refreshFamilyData(familyId: familyId, childId: childId)
        
        print("✅ FamilyService: Successfully updated child image base64")
    }
    
    /// Load child image from separate collection
    func loadChildImage(childId: String) async -> String? {
        print("🔍 FamilyService: Loading image for child: \(childId)")
        
        do {
            let document = try await db.collection("childImages").document(childId).getDocument()
            
            if let data = document.data(),
               let imageBase64 = data["imageBase64"] as? String {
                print("🔍 FamilyService: Successfully loaded image for child: \(childId)")
                return imageBase64
            } else {
                print("🔍 FamilyService: No image found for child: \(childId)")
                return nil
            }
        } catch {
            print("❌ FamilyService: Error loading child image: \(error)")
            return nil
        }
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
        pendingChildrenListener?.remove()
        
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
                self?.pendingChildrenListener?.remove()
                self?.currentFamily = nil
                self?.familyMembers = [:]
                self?.pendingChildren = []
                return
            }
            
            print("🔍 User has familyId: \(familyId)")
            
            // Stop old listeners
            self?.familyListener?.remove()
            self?.pendingChildrenListener?.remove()
            
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
            
            // Listen to pending children for this family
            print("🔍 Setting up pending children listener for familyId: \(familyId)")
            self?.pendingChildrenListener = self?.db.collection("pendingChildren")
                .whereField("familyId", isEqualTo: familyId)
                .addSnapshotListener { pendingSnapshot, pendingError in
                    if let pendingError = pendingError {
                        print("❌ Error listening to pending children: \(pendingError)")
                        return
                    }
                    
                    guard let documents = pendingSnapshot?.documents else {
                        print("ℹ️ No pending children documents found")
                        self?.pendingChildren = []
                        return
                    }
                    
                    print("🔍 Received \(documents.count) pending children documents")
                    for doc in documents {
                        print("🔍 Document ID: \(doc.documentID), Data: \(doc.data())")
                    }
                    
                    var loadedPendingChildren: [PendingFamilyChild] = []
                    for document in documents {
                        do {
                            let pendingChild = try Firestore.Decoder().decode(PendingFamilyChild.self, from: document.data())
                            loadedPendingChildren.append(pendingChild)
                        } catch {
                            print("❌ Error decoding pending child: \(error)")
                        }
                    }
                    
                    print("✅ Successfully loaded \(loadedPendingChildren.count) pending children")
                    print("🔍 Pending children details: \(loadedPendingChildren.map { "\($0.name) (\($0.status.rawValue))" })")
                    self?.pendingChildren = loadedPendingChildren
                }
        }
    }
    
    /// Get family members as an array
    func getFamilyMembers() -> [(String, FamilyMember)] {
        return Array(familyMembers)
    }
    
    /// Get children in the family (accepted only)
    func getChildren() -> [(String, FamilyMember)] {
        return familyMembers.filter { $0.value.role == .child }
    }
    
    /// Get all children (pending + accepted) as display items
    func getAllChildren() -> [ChildDisplayItem] {
        var children: [ChildDisplayItem] = []
        
        // Add accepted children
        for (id, member) in familyMembers where member.role == .child {
            children.append(ChildDisplayItem(from: member, id: id))
        }
        
        // Add pending children
        for pendingChild in pendingChildren {
            children.append(ChildDisplayItem(from: pendingChild))
        }
        
        return children.sorted { $0.joinedAt < $1.joinedAt }
    }
    
    /// Get all children IDs (pending + accepted) for map listening
    func getAllChildrenIds() -> [String] {
        var childIds: [String] = []
        
        // Add accepted children IDs
        childIds.append(contentsOf: familyMembers.filter { $0.value.role == .child }.map { $0.key })
        
        // Add pending children IDs
        childIds.append(contentsOf: pendingChildren.map { $0.id })
        
        return childIds
    }
    
    /// Get parents in the family
    func getParents() -> [(String, FamilyMember)] {
        return familyMembers.filter { $0.value.role == .parent }
    }
    
    /// Force refresh family data from Firestore
    func refreshFamilyData(familyId: String, childId: String? = nil) async {
        print("🔍 FamilyService: Force refreshing family data for family: \(familyId)")
        
        do {
            let familySnapshot = try await db.collection("families").document(familyId).getDocument()
            
            guard let familyData = familySnapshot.data() else {
                print("ℹ️ FamilyService: Family document not found during refresh")
                return
            }
            
            // Add the familyId as the id field for decoding
            var familyDataWithId = familyData
            familyDataWithId["id"] = familyId
            
            let family = try Firestore.Decoder().decode(Family.self, from: familyDataWithId)
            print("✅ FamilyService: Successfully refreshed family: \(family.name) with \(family.members.count) members")
            
            // Debug: Check if the child has imageBase64
            if let childId = childId, let childMember = family.members[childId] {
                print("🔍 FamilyService: Child member found in refreshed data")
                print("🔍 FamilyService: Child has imageBase64: \(childMember.imageBase64 != nil)")
                if let imageBase64 = childMember.imageBase64 {
                    print("🔍 FamilyService: ImageBase64 length: \(imageBase64.count)")
                }
            } else {
                print("🔍 FamilyService: Child member not found in refreshed data")
            }
            
            await MainActor.run {
                self.currentFamily = family
                self.familyMembers = family.members
            }
        } catch {
            print("❌ FamilyService: Error refreshing family data: \(error)")
        }
    }
    
    /// Update family name
    func updateFamilyName(_ newName: String) async throws {
        guard let family = currentFamily else {
            throw FamilyError.familyNotFound
        }
        
        print("🔍 Updating family name from '\(family.name)' to '\(newName)'")
        
        try await db.collection("families").document(family.id).updateData([
            "name": newName
        ])
        
        print("✅ Family name updated successfully")
    }
    
    /// Clean up listeners
    deinit {
        userListener?.remove()
        familyListener?.remove()
        pendingChildrenListener?.remove()
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
