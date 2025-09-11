import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - User Model
struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var userType: UserType
    var parents: [String] = []
    var children: [String] = []
    var createdAt: Date = Date()
    var lastActive: Date = Date()
    var isActive: Bool = true
    
    enum UserType: String, Codable, CaseIterable {
        case parent = "parent"
        case child = "child"
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
    
    // MARK: - Authentication State Management
    private func handleAuthStateChange(user: FirebaseAuth.User?) async {
        if let user = user {
            // User is signed in, fetch their profile
            await fetchUserProfile(userId: user.uid)
        } else {
            // User is signed out
            currentUser = nil
            isAuthenticated = false
        }
    }
    
    // MARK: - User Profile Management
    private func fetchUserProfile(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                currentUser = try document.data(as: User.self)
                isAuthenticated = true
            } else {
                // User document doesn't exist, create it
                await createUserProfile(userId: userId)
            }
        } catch {
            print("Error fetching user profile: \(error)")
            errorMessage = "Failed to load user profile"
        }
    }
    
    private func createUserProfile(userId: String) async {
        guard let firebaseUser = auth.currentUser else { return }
        
        let newUser = User(
            name: firebaseUser.displayName ?? "User",
            email: firebaseUser.email ?? "",
            userType: .parent // Default to parent, can be changed later
        )
        
        do {
            try db.collection("users").document(userId).setData(from: newUser)
            currentUser = newUser
            isAuthenticated = true
        } catch {
            print("Error creating user profile: \(error)")
            errorMessage = "Failed to create user profile"
        }
    }
    
    // MARK: - Authentication Methods
    func signUp(email: String, password: String, name: String, userType: User.UserType) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            
            // Update display name
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            // Create user profile in Firestore
            let newUser = User(
                name: name,
                email: email,
                userType: userType
            )
            
            try db.collection("users").document(result.user.uid).setData(from: newUser)
            
            // The auth state listener will handle the rest
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await auth.signIn(withEmail: email, password: password)
            // The auth state listener will handle the rest
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try auth.signOut()
            // The auth state listener will handle the rest
        } catch {
            errorMessage = error.localizedDescription
        }
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
    
    // MARK: - User Management
    func updateUserProfile(_ user: User) async {
        guard let userId = user.id else { return }
        
        do {
            try db.collection("users").document(userId).setData(from: user, merge: true)
            currentUser = user
        } catch {
            errorMessage = "Failed to update profile"
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