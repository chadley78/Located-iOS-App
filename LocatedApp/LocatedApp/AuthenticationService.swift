import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Model
struct User: Codable, Identifiable {
    var id: String?
    var name: String
    var email: String
    var userType: UserType
    var parents: [String] = []
    var children: [String] = []
    var pendingChildren: [PendingChild] = []
    var createdAt: Date = Date()
    var lastActive: Date = Date()
    var isActive: Bool = true
    
    enum UserType: String, Codable, CaseIterable {
        case parent = "parent"
        case child = "child"
    }
}

// MARK: - Pending Child Model
struct PendingChild: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let invitationCode: String
    let createdAt: Date
    let invitationId: String
    
    init(id: String, name: String, email: String, invitationCode: String, createdAt: Date = Date(), invitationId: String) {
        self.id = id
        self.name = name
        self.email = email
        self.invitationCode = invitationCode
        self.createdAt = createdAt
        self.invitationId = invitationId
    }
}

// MARK: - Authentication Service
@MainActor
class AuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        // Listen for authentication state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task {
                await self?.handleAuthStateChange(user: user)
            }
        }
    }
    
    private func handleAuthStateChange(user: FirebaseAuth.User?) async {
        if let user = user {
            // User is signed in
            await fetchUserProfile(userId: user.uid)
            isAuthenticated = true
        } else {
            // User is signed out
            currentUser = nil
            isAuthenticated = false
        }
    }
    
    // MARK: - Authentication Methods
    func signUp(email: String, password: String, name: String, userType: User.UserType) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let newUser = User(
                id: authResult.user.uid,
                name: name,
                email: email,
                userType: userType
            )
            
            // Save user profile to Firestore
            try await saveUserProfile(newUser)
            currentUser = newUser
            isAuthenticated = true
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            await fetchUserProfile(userId: authResult.user.uid)
            isAuthenticated = true
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() async {
        print("🔐 Starting sign out process...")
        
        do {
            // Clear any pending operations
            isLoading = false
            errorMessage = nil
            
            // Sign out from Firebase Auth
            try auth.signOut()
            
            // Clear user data
            currentUser = nil
            isAuthenticated = false
            
            print("🔐 Sign out completed successfully")
            
        } catch {
            print("❌ Error during sign out: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Service Cleanup
    func cleanupServices() {
        print("🔐 Cleaning up all services...")
        // This method will be called by views that have access to the services
        // The actual cleanup will be handled by the individual views
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await auth.sendPasswordReset(withEmail: email)
            errorMessage = "Password reset email sent"
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - User Profile Management
    private func fetchUserProfile(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data() {
                var user = try Firestore.Decoder().decode(User.self, from: data)
                user.id = userId
                currentUser = user
            }
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }
    
    private func saveUserProfile(_ user: User) async throws {
        let userData = try Firestore.Encoder().encode(user)
        try await db.collection("users").document(user.id ?? "").setData(userData)
    }
    
    func updateUserProfile(_ user: User) async {
        do {
            try await saveUserProfile(user)
            currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateLastActive() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "lastActive": Date()
            ])
        } catch {
            print("Error updating last active: \(error)")
        }
    }
}