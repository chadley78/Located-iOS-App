import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Family Invitation Service
@MainActor
class FamilyInvitationService: ObservableObject {
    @Published var pendingInvitations: [FamilyInvitation] = []
    @Published var hasPendingInvitations: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    nonisolated private var listener: ListenerRegistration?
    
    init() {
        // Start listening for invitations when service is created
        if let userId = Auth.auth().currentUser?.uid {
            startListeningForInvitations(userId: userId)
        }
    }
    
    /// Start listening for family invitations for the current user
    func startListeningForInvitations(userId: String) {
        print("🔍 Starting to listen for family invitations for user: \(userId)")
        
        // Listen for invitations where this user is the target
        // We'll check invitations by looking for unused invitations
        Task { @MainActor in
            listener = db.collection("invitations")
            .whereField("usedBy", isEqualTo: NSNull())
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening for invitations: \(error)")
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("🔍 No invitation documents found")
                    self.pendingInvitations = []
                    self.hasPendingInvitations = false
                    return
                }
                
                print("🔍 Found \(documents.count) invitation documents")
                
                // Filter invitations that haven't expired
                let now = Date()
                let validInvitations = documents.compactMap { document -> FamilyInvitation? in
                    do {
                        let invitation = try Firestore.Decoder().decode(FamilyInvitation.self, from: document.data())
                        
                        // Check if invitation has expired
                        if invitation.isExpired {
                            print("🔍 Invitation \(invitation.id) has expired")
                            return nil
                        }
                        
                        print("🔍 Valid invitation found: \(invitation.id) for \(invitation.childName)")
                        return invitation
                    } catch {
                        print("❌ Error decoding invitation: \(error)")
                        return nil
                    }
                }
                
                self.pendingInvitations = validInvitations
                self.hasPendingInvitations = !validInvitations.isEmpty
                print("🔍 Final pending invitations count: \(self.pendingInvitations.count)")
            }
        }
    }
    
    /// Accept a family invitation using an invite code
    func acceptInvitation(inviteCode: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FamilyInvitationError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔍 Accepting invitation with code: \(inviteCode)")
            
            // Get invitation document
            let invitationDoc = try await db.collection("invitations").document(inviteCode).getDocument()
            
            guard invitationDoc.exists else {
                throw FamilyInvitationError.invalidInvitationCode
            }
            
            let invitationData = invitationDoc.data()!
            
            // Check if invitation has expired
            if let expiresAt = invitationData["expiresAt"] as? Timestamp {
                let expirationDate = expiresAt.dateValue()
                if Date() > expirationDate {
                    throw FamilyInvitationError.invitationExpired
                }
            }
            
            // Check if invitation has already been used
            if let usedBy = invitationData["usedBy"] as? String, !usedBy.isEmpty {
                throw FamilyInvitationError.invitationUsed
            }
            
            // Get child's user data
            let childDoc = try await db.collection("users").document(userId).getDocument()
            guard childDoc.exists else {
                throw FamilyInvitationError.userNotFound
            }
            
            let childData = childDoc.data()!
            let childName = childData["name"] as? String ?? "Child"
            
            // Add child to family
            let familyId = invitationData["familyId"] as! String
            try await db.collection("families").document(familyId).updateData([
                "members.\(userId)": [
                    "role": "child",
                    "name": childName,
                    "joinedAt": Timestamp(date: Date())
                ]
            ])
            
            // Update child's user document with familyId
            try await db.collection("users").document(userId).updateData([
                "familyId": familyId
            ])
            
            // Mark invitation as used
            try await db.collection("invitations").document(inviteCode).updateData([
                "usedBy": userId,
                "usedAt": Timestamp(date: Date())
            ])
            
            print("✅ Successfully accepted invitation: \(inviteCode)")
            
            await MainActor.run {
                self.isLoading = false
            }
            
        } catch {
            print("❌ Error accepting invitation: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Create a family invitation (for parents)
    func createInvitation(familyId: String, childName: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FamilyInvitationError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Verify the user is a parent in this family
            let familyDoc = try await db.collection("families").document(familyId).getDocument()
            guard familyDoc.exists else {
                throw FamilyInvitationError.familyNotFound
            }
            
            let familyData = familyDoc.data()!
            let members = familyData["members"] as! [String: [String: Any]]
            
            guard let memberData = members[userId],
                  let role = memberData["role"] as? String,
                  role == "parent" else {
                throw FamilyInvitationError.notAuthorized
            }
            
            // Generate a unique 6-character alphanumeric invite code
            let inviteCode = generateInviteCode()
            
            // Create invitation document
            let invitationData: [String: Any] = [
                "familyId": familyId,
                "createdBy": userId,
                "childName": childName,
                "createdAt": Timestamp(date: Date()),
                "expiresAt": Timestamp(date: Date().addingTimeInterval(24 * 60 * 60)), // 24 hours
                "usedBy": NSNull(),
                "usedAt": NSNull()
            ]
            
            try await db.collection("invitations").document(inviteCode).setData(invitationData)
            
            print("✅ Invitation created successfully: \(inviteCode)")
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return inviteCode
            
        } catch {
            print("❌ Error creating invitation: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Generate a unique 6-character alphanumeric invite code
    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let code = String((0..<6).map { _ in chars.randomElement()! })
        return code
    }
    
    /// Stop listening for invitations
    nonisolated func stopListening() {
        listener?.remove()
        listener = nil
        Task { @MainActor in
            pendingInvitations = []
            hasPendingInvitations = false
        }
        print("🛑 Stopped listening for family invitations")
    }
    
    deinit {
        stopListening()
    }
}

// MARK: - Family Invitation Errors
enum FamilyInvitationError: LocalizedError {
    case notAuthenticated
    case invalidInvitationCode
    case invitationExpired
    case invitationUsed
    case familyNotFound
    case userNotFound
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated."
        case .invalidInvitationCode:
            return "Invalid invitation code."
        case .invitationExpired:
            return "Invitation has expired."
        case .invitationUsed:
            return "Invitation has already been used."
        case .familyNotFound:
            return "Family not found."
        case .userNotFound:
            return "User not found."
        case .notAuthorized:
            return "You are not authorized to create invitations for this family."
        }
    }
}
