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
    nonisolated(unsafe) private var listener: ListenerRegistration?
    
    init() {
        // Don't automatically start listening - it causes permissions errors
        // Invitations will be handled manually when needed
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
    
    /// Accept a family invitation using Cloud Function via HTTP
    func acceptInvitation(inviteCode: String) async throws -> [String: Any] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FamilyInvitationError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔍 Accepting invitation using Cloud Function with code: \(inviteCode)")
            
            // Get Firebase ID token for authentication
            guard let idToken = try await Auth.auth().currentUser?.getIDToken() else {
                throw FamilyInvitationError.notAuthenticated
            }
            
            // Call the acceptInvitation Cloud Function via HTTP
            let url = URL(string: "https://us-central1-located-d9dce.cloudfunctions.net/acceptInvitation")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            
            let requestBody = [
                "data": [
                    "inviteCode": inviteCode
                ]
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw FamilyInvitationError.invalidInvitationCode
            }
            
            // Parse the response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let success = result["success"] as? Bool,
                  success else {
                throw FamilyInvitationError.invalidInvitationCode
            }
            
            print("✅ Successfully accepted invitation: \(inviteCode)")
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return result
            
        } catch {
            print("❌ Error accepting invitation: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    /// Create a family invitation and pending child using Cloud Function via HTTP
    func createInvitation(familyId: String, childName: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FamilyInvitationError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔍 Creating invitation and pending child using Cloud Function for familyId: \(familyId)")
            
            // Get Firebase ID token for authentication
            guard let idToken = try await Auth.auth().currentUser?.getIDToken() else {
                throw FamilyInvitationError.notAuthenticated
            }
            
            // Call the createInvitation Cloud Function via HTTP
            let url = URL(string: "https://us-central1-located-d9dce.cloudfunctions.net/createInvitation")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            
            let requestBody = [
                "data": [
                    "familyId": familyId,
                    "childName": childName
                ]
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw FamilyInvitationError.familyNotFound
            }
            
            // Parse the response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let inviteCode = result["inviteCode"] as? String else {
                throw FamilyInvitationError.familyNotFound
            }
            
            print("✅ Invitation and pending child created successfully: \(inviteCode)")
            
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
    
    /// Generate a shareable invitation link
    func generateInvitationLink(inviteCode: String) -> String {
        // Deep link format: located://invite/ABC123
        return "located://invite/\(inviteCode)"
    }
    
    /// Generate a universal link (for web fallback)
    func generateUniversalLink(inviteCode: String) -> String {
        // Universal link format: https://located.app/invite/ABC123
        return "https://located.app/invite/\(inviteCode)"
    }
    
    /// Generate a unique 6-character alphanumeric invite code
    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let code = String((0..<6).map { _ in chars.randomElement()! })
        return code
    }
    
    /// Stop listening for invitations
    nonisolated func stopListening() {
        Task { @MainActor in
            listener?.remove()
            listener = nil
            pendingInvitations = []
            hasPendingInvitations = false
        }
        print("🛑 Stopped listening for family invitations")
    }
    
    /// Synchronous cleanup for deinit
    nonisolated private func cleanup() {
        listener?.remove()
        listener = nil
        print("🛑 Cleaned up family invitation service")
    }
    
    deinit {
        cleanup()
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
