import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Model
struct User: Codable, Identifiable {
    var id: String?
    var name: String
    var email: String
    var userType: UserType
    var familyId: String? // Reference to the family this user belongs to
    var createdAt: Date
    var lastActive: Date
    var isActive: Bool
    var fcmTokens: [String]? // For push notifications - optional for backward compatibility
    
    // Legacy fields for backward compatibility (will be ignored during encoding)
    private var children: [String]?
    private var parents: [String]?
    private var pendingChildren: [PendingChild]?
    
    enum UserType: String, Codable, CaseIterable {
        case parent = "parent"
        case child = "child"
    }
    
    // Custom coding keys to handle legacy fields
    enum CodingKeys: String, CodingKey {
        case id, name, email, userType, familyId, createdAt, lastActive, isActive, fcmTokens
        case children, parents, pendingChildren // Legacy fields
    }
    
    // Custom initializer for creating new users
    init(id: String? = nil, name: String, email: String, userType: UserType, familyId: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.userType = userType
        self.familyId = familyId
        self.createdAt = Date()
        self.lastActive = Date()
        self.isActive = true
        self.fcmTokens = []
        
        // Legacy fields (nil for new users)
        self.children = nil
        self.parents = nil
        self.pendingChildren = nil
    }
    
    // Custom initializer to handle missing fields from Firestore
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        userType = try container.decode(UserType.self, forKey: .userType)
        familyId = try container.decodeIfPresent(String.self, forKey: .familyId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastActive = try container.decodeIfPresent(Date.self, forKey: .lastActive) ?? Date()
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        fcmTokens = try container.decodeIfPresent([String].self, forKey: .fcmTokens)
        
        // Legacy fields (ignored)
        children = try container.decodeIfPresent([String].self, forKey: .children)
        parents = try container.decodeIfPresent([String].self, forKey: .parents)
        pendingChildren = try container.decodeIfPresent([PendingChild].self, forKey: .pendingChildren)
    }
}

// Legacy struct for backward compatibility
struct PendingChild: Codable {
    let id: String
    let name: String
    let email: String
    let invitationCode: String
    let invitationId: String
}

// MARK: - Authentication Service
@MainActor
class AuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isInitializing = true
    @Published var errorMessage: String?
    @Published var shouldShowWelcome = false
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var notificationService: NotificationService?
    private var userListener: ListenerRegistration?
    
    init() {
        // Listen for authentication state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task {
                await self?.handleAuthStateChange(user: user)
            }
        }
    }
    
    func setNotificationService(_ notificationService: NotificationService) {
        self.notificationService = notificationService
    }
    
    private func handleAuthStateChange(user: FirebaseAuth.User?) async {
        if let user = user {
            // User is signed in - fetch profile first, then set authenticated
            await fetchUserProfile(userId: user.uid)
            // Start listening to user document changes for family removal detection
            startUserDocumentListener(userId: user.uid)
            // Only set authenticated after currentUser is loaded
            if currentUser != nil {
                // If we should show welcome, don't set authenticated yet
                if !shouldShowWelcome {
                    isAuthenticated = true
                    print("🔍 User authenticated successfully: \(currentUser?.name ?? "Unknown") (\(currentUser?.userType.rawValue ?? "unknown"))")
                } else {
                    print("🔍 User authenticated but waiting for welcome screen: \(currentUser?.name ?? "Unknown") (\(currentUser?.userType.rawValue ?? "unknown")), shouldShowWelcome = \(shouldShowWelcome)")
                }
            }
        } else {
            // User is signed out
            currentUser = nil
            isAuthenticated = false
            shouldShowWelcome = false
            userListener?.remove()
            userListener = nil
            print("🔍 User signed out")
        }
        
        // Mark initialization as complete
        isInitializing = false
    }
    
    func completeWelcomeFlow() {
        shouldShowWelcome = false
        isAuthenticated = true
        print("🔍 Welcome flow completed, user now authenticated")
    }
    
    // MARK: - User Document Listener
    private func startUserDocumentListener(userId: String) {
        // Remove existing listener
        userListener?.remove()
        
        userListener = db.collection("users").document(userId).addSnapshotListener { [weak self] documentSnapshot, error in
            if let error = error {
                print("❌ Error listening to user document: \(error)")
                return
            }
            
            guard let document = documentSnapshot,
                  let data = document.data() else {
                print("ℹ️ User document not found or empty")
                return
            }
            
            // Check if familyId was removed (indicating child was removed from family)
            if let currentUser = self?.currentUser,
               currentUser.userType == .child,
               currentUser.familyId != nil,
               data["familyId"] == nil {
                print("🔍 Child was removed from family - signing out")
                Task {
                    await self?.signOut()
                }
            }
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
            // isAuthenticated will be set by handleAuthStateChange after currentUser is loaded
            
            // Register FCM token after successful sign in
            if let notificationService = notificationService {
                await notificationService.registerFCMToken()
            }
            
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
            // Configure better email settings for improved deliverability
            let actionCodeSettings = ActionCodeSettings()
            
            // Use a custom domain URL for better branding
            if let customURL = URL(string: "https://located.app/reset-password") {
                actionCodeSettings.url = customURL
                actionCodeSettings.handleCodeInApp = false
            }
            
            // iOS bundle ID for deep linking
            actionCodeSettings.iOSBundleID = Bundle.main.bundleIdentifier
            
            // Send password reset with improved settings
            try await auth.sendPasswordReset(withEmail: email, actionCodeSettings: actionCodeSettings)
            
            await MainActor.run {
                self.errorMessage = "Password reset email sent to \(email). Please check your inbox and spam folder."
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to send reset email: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - User Profile Management
    private func fetchUserProfile(userId: String) async {
        print("🔍 Fetching user profile for userId: \(userId)")
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data() {
                print("🔍 User document data: \(data)")
                var user = try Firestore.Decoder().decode(User.self, from: data)
                user.id = userId
                print("🔍 Decoded user: name=\(user.name), email=\(user.email), userType=\(user.userType)")
                currentUser = user
            } else {
                print("❌ No user document found for userId: \(userId)")
                // Add a small delay and try again before creating default
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                let retryDocument = try await db.collection("users").document(userId).getDocument()
                if let retryData = retryDocument.data() {
                    print("🔍 User document found on retry: \(retryData)")
                    var user = try Firestore.Decoder().decode(User.self, from: retryData)
                    user.id = userId
                    print("🔍 Decoded user on retry: name=\(user.name), email=\(user.email), userType=\(user.userType)")
                    currentUser = user
                } else {
                    print("❌ Still no user document found after retry, creating default")
                    // Create a default user document if none exists
                    await createDefaultUserDocument(userId: userId)
                }
            }
        } catch {
            print("❌ Error fetching user profile: \(error)")
            // Try to create a default user document on error
            await createDefaultUserDocument(userId: userId)
        }
    }
    
    private func createDefaultUserDocument(userId: String) async {
        print("🔍 Creating default user document for userId: \(userId)")
        guard let firebaseUser = auth.currentUser else {
            print("❌ No Firebase user found")
            return
        }
        
        // Try to determine user type from email or other context
        let userType: User.UserType
        if let email = firebaseUser.email, email.contains("@temp.located.app") {
            // Temporary child accounts have this email pattern
            userType = .child
            print("🔍 Detected child user from email pattern")
        } else {
            // Default to parent for regular accounts
            userType = .parent
            print("🔍 Defaulting to parent user type")
        }
        
        let defaultUser = User(
            id: userId,
            name: firebaseUser.displayName ?? "User",
            email: firebaseUser.email ?? "",
            userType: userType
        )
        
        do {
            try await saveUserProfile(defaultUser)
            currentUser = defaultUser
            print("🔍 Created default user document with userType: \(userType.rawValue)")
        } catch {
            print("❌ Error creating default user document: \(error)")
        }
    }
    
    func saveUserProfile(_ user: User) async throws {
        print("🔍 Saving user profile: name=\(user.name), userType=\(user.userType.rawValue), id=\(user.id ?? "nil")")
        let userData = try Firestore.Encoder().encode(user)
        print("🔍 Encoded user data: \(userData)")
        try await db.collection("users").document(user.id ?? "").setData(userData)
        print("🔍 Successfully saved user profile to Firestore")
    }
    
    func updateUserProfile(_ user: User) async {
        do {
            try await saveUserProfile(user)
            currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Force refresh the user profile from Firestore
    func refreshUserProfile() async {
        guard let userId = auth.currentUser?.uid else {
            print("❌ Cannot refresh user profile: no authenticated user")
            return
        }
        
        print("🔄 Force refreshing user profile for userId: \(userId)")
        await fetchUserProfile(userId: userId)
    }
    
    func updateUserType(_ userType: User.UserType) async {
        guard var user = currentUser else { return }
        user.userType = userType
        await updateUserProfile(user)
        print("🔍 Updated user type to: \(userType.rawValue)")
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
    
    deinit {
        userListener?.remove()
        print("🔐 AuthenticationService deallocated")
    }
}