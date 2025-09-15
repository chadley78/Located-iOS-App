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
struct FamilyMember: Codable {
    let role: FamilyRole
    let name: String
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case role, name, joinedAt
    }
}

/// Roles within a family
enum FamilyRole: String, Codable, CaseIterable {
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
    
    init() {
        // Listen for family changes
        if let userId = auth.currentUser?.uid {
            listenToFamily(userId: userId)
        }
    }
    
    // MARK: - Family Management
    
    /// Create a new family
    func createFamily(name: String) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw FamilyError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let familyId = UUID().uuidString
            let family = Family(
                id: familyId,
                name: name,
                createdBy: userId,
                createdAt: Date(),
                members: [
                    userId: FamilyMember(
                        role: .parent,
                        name: auth.currentUser?.displayName ?? "Parent",
                        joinedAt: Date()
                    )
                ]
            )
            
            print("🔍 Creating family with ID: \(familyId)")
            print("🔍 Family data: \(family)")
            
            // First, clear any existing familyId from user document
            try await db.collection("users").document(userId).updateData([
                "familyId": FieldValue.delete()
            ])
            print("✅ Cleared existing familyId from user document")
            
            // Create family document
            try await db.collection("families").document(familyId).setData(from: family)
            print("✅ Family document created successfully")
            
            // Update user's familyId
            try await db.collection("users").document(userId).updateData([
                "familyId": familyId
            ])
            print("✅ Updated user's familyId to: \(familyId)")
            
            await MainActor.run {
                self.currentFamily = family
                self.familyMembers = family.members
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
    
    /// Listen to family changes
    private func listenToFamily(userId: String) {
        // First get the user's familyId
        db.collection("users").document(userId).addSnapshotListener { [weak self] documentSnapshot, error in
            if let error = error {
                print("❌ Error listening to user document: \(error)")
                return
            }
            
            guard let document = documentSnapshot,
                  let data = document.data(),
                  let familyId = data["familyId"] as? String else {
                print("ℹ️ User has no familyId")
                return
            }
            
            // Listen to family document
            self?.db.collection("families").document(familyId).addSnapshotListener { familySnapshot, familyError in
                if let familyError = familyError {
                    print("❌ Error listening to family document: \(familyError)")
                    return
                }
                
                guard let familyData = familySnapshot?.data() else {
                    print("ℹ️ Family document not found")
                    return
                }
                
                do {
                    let family = try Firestore.Decoder().decode(Family.self, from: familyData)
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
