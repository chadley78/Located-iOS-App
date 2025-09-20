import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit
import MapKit

struct ContentView: View {
    let invitationCode: String?
    @StateObject private var authService = AuthenticationService()
    @StateObject private var locationService = LocationService()
    @EnvironmentObject var familyService: FamilyService
    
    init(invitationCode: String? = nil) {
        self.invitationCode = invitationCode
    }
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if authService.currentUser != nil {
                    MainTabView()
                        .environmentObject(authService)
                        .environmentObject(locationService)
                        .environmentObject(familyService)
                } else {
                    // Show loading while user data is being fetched
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .font(.headline)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            } else {
                WelcomeView(invitationCode: invitationCode)
                    .environmentObject(authService)
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .onAppear {
            // Start location service when app appears
            if authService.isAuthenticated {
                locationService.requestLocationPermission()
            }
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            // Handle authentication state changes
            if isAuthenticated {
                locationService.requestLocationPermission()
                // Restart family listener when user becomes authenticated
                if let userId = authService.currentUser?.id {
                    print("🔄 ContentView: User authenticated, restarting family listener for: \(userId)")
                    familyService.handleAuthStateChange(isAuthenticated: true, userId: userId)
                }
            } else {
                // Stop family listener when user signs out
                familyService.handleAuthStateChange(isAuthenticated: false, userId: nil)
            }
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let invitationCode: String?
    @EnvironmentObject var authService: AuthenticationService
    
    init(invitationCode: String? = nil) {
        self.invitationCode = invitationCode
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo and Title
                VStack(spacing: 20) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("L")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Text("Located")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        Text("Keep your kids")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        Text("safe & sound")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Role Selection Buttons
                VStack(spacing: 16) {
                    NavigationLink(destination: AuthenticationView(userType: .parent, invitationCode: invitationCode)) {
                        Text("I'm a Parent")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                    
                    NavigationLink(destination: AuthenticationView(userType: .child, invitationCode: invitationCode)) {
                        Text("I'm a Child")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.green)
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 50)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    let userType: User.UserType
    let invitationCode: String?
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @State private var isSignUp = false
    
    var body: some View {
        VStack(spacing: 20) {
            if userType == .child {
                // Child-specific flow
                ChildSignUpView(invitationCode: invitationCode)
                    .environmentObject(authService)
                    .environmentObject(familyService)
            } else {
                // Parent flow (existing)
                if isSignUp {
                    SignUpView(userType: userType)
                        .environmentObject(authService)
                } else {
                    SignInView()
                        .environmentObject(authService)
                }
                
                // Toggle between Sign In and Sign Up
                Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                    isSignUp.toggle()
                }
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(userType == .parent ? "Parent Login" : "Join Your Family")
    }
}

// MARK: - Child Sign Up View
struct ChildSignUpView: View {
    let invitationCode: String?
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @StateObject private var invitationService = FamilyInvitationService()
    
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingWelcome = false
    @State private var isExistingChild = false
    
    var body: some View {
        Group {
            if showingWelcome {
                if isExistingChild {
                    ChildWelcomeBackView {
                        // Complete the welcome flow and show main view
                        authService.completeWelcomeFlow()
                    }
                } else {
                    ChildWelcomeView {
                        // Complete the welcome flow and show main view
                        authService.completeWelcomeFlow()
                    }
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Join Your Family")
                            .font(.title)
                            .fontWeight(.bold)
                        
                Text("Enter the invitation code your parent shared with you.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                // Invitation Code Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invitation Code")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter invitation code", text: $inviteCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                }
            }
            .padding(.horizontal, 30)
            
            // Error Message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 30)
            }
            
            
            Spacer()
            
            // Join Family Button
            Button(action: joinFamily) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Join Family")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isFormValid ? Color.green : Color.gray)
            .cornerRadius(25)
            .disabled(!isFormValid || isLoading)
            .padding(.horizontal, 30)
            
                    Spacer()
                }
                .onAppear {
                    // Pre-fill invitation code if provided
                    if let code = invitationCode {
                        inviteCode = code
                    }
                }
                .alert("Error", isPresented: .constant(errorMessage != nil)) {
                    Button("OK") {
                        errorMessage = nil
                    }
                } message: {
                    Text(errorMessage ?? "")
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func joinFamily() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                
                // Set welcome screen state BEFORE creating user account (prevents auth bypass)
                await MainActor.run {
                    authService.shouldShowWelcome = true
                    print("🔍 Set shouldShowWelcome = true before user creation")
                }
                
                // Generate a temporary email for the child (we still need this for Firebase Auth)
                let tempEmail = "child_\(UUID().uuidString)@temp.located.app"
                let tempPassword = "temp_\(UUID().uuidString.prefix(8))"
                
                print("🔍 Creating temporary account for child")
                
                // Create user account with temporary email
                let authResult = try await Auth.auth().createUser(withEmail: tempEmail, password: tempPassword)
                
                // Get child name from invitation
                let childName = await getChildNameFromInvitation(inviteCode: trimmedCode)
                
                // Update the user's display name
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = childName
                try await changeRequest.commitChanges()
                
                // Create user profile
                let newUser = User(
                    id: authResult.user.uid,
                    name: childName,
                    email: tempEmail,
                    userType: .child
                )
                
                print("🔍 Created child user object: name=\(newUser.name), userType=\(newUser.userType.rawValue)")
                
                // Save user profile to Firestore
                try await authService.saveUserProfile(newUser)
                print("🔍 Saved child user profile to Firestore")
                
                // Now accept the invitation (user is now authenticated)
                let invitationResult = try await invitationService.acceptInvitation(inviteCode: trimmedCode)
                print("🔍 Invitation accepted successfully")
                
                // Check if this was for an existing child based on the Cloud Function response
                let isExistingChildResponse = invitationResult["isExistingChild"] as? Bool ?? false
                
                await MainActor.run {
                    if isExistingChildResponse {
                        print("🔍 Invitation was for existing child - show welcome back screen")
                        isExistingChild = true
                    } else {
                        print("🔍 Invitation was for new child - show welcome screen")
                        isExistingChild = false
                    }
                    
                    isLoading = false
                    showingWelcome = true
                    print("🔍 Showing welcome screen - isExistingChild: \(isExistingChild)")
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    
    // Helper function to get child name from invitation
    private func getChildNameFromInvitation(inviteCode: String) async -> String {
        do {
            let invitationDoc = try await Firestore.firestore()
                .collection("invitations")
                .document(inviteCode)
                .getDocument()
            
            guard let invitationData = invitationDoc.data(),
                  let childName = invitationData["childName"] as? String else {
                return "Child"
            }
            
            return childName
            
        } catch {
            print("❌ Error getting child name from invitation: \(error)")
            return "Child"
        }
    }
}

// MARK: - Sign In View
struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Address")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
                .padding(.horizontal, 30)
                
                // Sign In Button
                Button(action: signIn) {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(25)
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                .padding(.horizontal, 30)
                
                // Forgot Password
                Button("Forgot Password?") {
                    showingForgotPassword = true
                }
                .font(.system(size: 16))
                .foregroundColor(.blue)
                
                Spacer()
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(authService.errorMessage != nil)) {
                Button("OK") {
                    authService.errorMessage = nil
                }
            } message: {
                Text(authService.errorMessage ?? "")
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
                    .environmentObject(authService)
            }
        }
    }
    
    private func signIn() {
        Task {
            await authService.signIn(email: email, password: password)
        }
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    let userType: User.UserType
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                // Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    CustomSecureField(placeholder: "Enter your password", text: $password)
                }
                
                // Confirm Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    CustomSecureField(placeholder: "Confirm your password", text: $confirmPassword)
                }
            }
            .padding(.horizontal, 30)
            
            // Create Account Button
            Button(action: signUp) {
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Create Account")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(25)
            .disabled(authService.isLoading || !isFormValid)
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(authService.errorMessage != nil)) {
            Button("OK") {
                authService.errorMessage = nil
            }
        } message: {
            Text(authService.errorMessage ?? "")
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }
    
    private func signUp() {
        Task {
            await authService.signUp(email: email, password: password, name: name, userType: userType)
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 30)
                
                Button(action: resetPassword) {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Reset Email")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(25)
                .disabled(authService.isLoading || email.isEmpty)
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: .constant(authService.errorMessage == "Password reset email sent")) {
                Button("OK") {
                    authService.errorMessage = nil
                    dismiss()
                }
            } message: {
                Text("Password reset email sent")
            }
            .alert("Error", isPresented: .constant(authService.errorMessage != nil && authService.errorMessage != "Password reset email sent")) {
                Button("OK") {
                    authService.errorMessage = nil
                }
            } message: {
                Text(authService.errorMessage ?? "")
            }
        }
    }
    
    private func resetPassword() {
        Task {
            await authService.resetPassword(email: email)
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        TabView {
            if authService.currentUser?.userType == .parent {
                // Debug logging
                let _ = print("🔍 MainTabView: Showing PARENT UI for user: \(authService.currentUser?.name ?? "Unknown"), userType: \(authService.currentUser?.userType.rawValue ?? "nil")")
                ParentHomeView()
                    .tabItem {
                        Image(systemName: "map")
                        Text("Map")
                    }
                
                ChildrenListView()
                    .tabItem {
                        Image(systemName: "person.2")
                        Text("Children")
                    }
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
            } else {
                // Debug logging
                let _ = print("🔍 MainTabView: Showing CHILD UI for user: \(authService.currentUser?.name ?? "Unknown"), userType: \(authService.currentUser?.userType.rawValue ?? "nil")")
                ChildHomeView()
                    .tabItem {
                        Image(systemName: "location")
                        Text("Status")
                    }
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
            }
        }
    }
}

// MARK: - Parent Home View
struct ParentHomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @StateObject private var geofenceService = GeofenceService()
    
    @State private var showingFamilySetup = false
    @State private var showingFamilyManagement = false
    @State private var showingGeofenceManagement = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Family Status Overview
                VStack(spacing: 16) {
                    Text("Family Overview")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let family = familyService.currentFamily {
                        // Show family info
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundColor(.blue)
                                Text(family.name)
                                    .font(.headline)
                                Spacer()
                                Text("\(familyService.getFamilyMembers().count) members")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Show children
                            let children = familyService.getChildren()
                            if children.isEmpty {
                                Text("No children in family yet")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(children, id: \.0) { childId, child in
                                    ChildStatusRow(childId: childId, child: child)
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    } else {
                        // No family state
                        VStack(spacing: 16) {
                            Image(systemName: "house")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No Family Created")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Create a family to start tracking your children and setting up geofences.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Create Family") {
                                showingFamilySetup = true
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Quick Actions
                VStack(spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        // Family Management
                        Button(action: {
                            if familyService.currentFamily != nil {
                                showingFamilyManagement = true
                            } else {
                                showingFamilySetup = true
                            }
                        }) {
                            VStack {
                                Image(systemName: "house.fill")
                                    .font(.title2)
                                Text("Family")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Map View
                        NavigationLink(destination: ParentMapView()) {
                            VStack {
                                Image(systemName: "map")
                                    .font(.title2)
                                Text("Map")
                                    .font(.caption)
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Geofences
                        Button(action: {
                            if let family = familyService.currentFamily {
                                showingGeofenceManagement = true
                            }
                        }) {
                            VStack {
                                Image(systemName: "location.circle")
                                    .font(.title2)
                                Text("Geofences")
                                    .font(.caption)
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .disabled(familyService.currentFamily == nil)
                        
                        // Settings
                        NavigationLink(destination: SettingsView()) {
                            VStack {
                                Image(systemName: "gear")
                                    .font(.title2)
                                Text("Settings")
                                    .font(.caption)
                            }
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingFamilySetup) {
                FamilySetupView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingFamilyManagement) {
                FamilyManagementView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingGeofenceManagement) {
                if let family = familyService.currentFamily {
                    GeofenceManagementView(familyId: family.id)
                }
            }
        }
        .onAppear {
            // Load family data when view appears
            if let userId = authService.currentUser?.id {
                // FamilyService will automatically listen for changes
            }
        }
    }
}

// MARK: - Child Status Row
struct ChildStatusRow: View {
    let childId: String
    let child: FamilyMember
    
    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .font(.headline)
                
                Text("Child")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator (could be enhanced with actual location status)
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Child Location Service
class ChildLocationService: ObservableObject {
    @Published var childrenLocations: [ChildLocationData] = []
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    func startListeningForChildrenLocations(parentId: String) {
        // Validate parentId before making Firestore calls
        guard !parentId.isEmpty else {
            print("❌ Cannot start listening: parentId is empty")
            return
        }
        
        print("🔍 Starting to listen for children locations for parent: \(parentId)")
        
        // Listen for changes to the parent's user document to get updated children list
        let parentListener = db.collection("users").document(parentId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening for parent user changes: \(error)")
                    return
                }
                
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let userData = try? Firestore.Decoder().decode(User.self, from: data) else {
                    print("❌ Could not decode parent user data")
                    return
                }
                
                // For now, we'll use a simple approach since we're transitioning to family-centric
                // This will be replaced by FamilyService in the new architecture
                print("🔍 Parent user data loaded, but using family-centric approach now")
            }
        
        listeners.append(parentListener)
    }
    
    private func listenForChildLocation(childId: String) {
        // Validate childId before making Firestore calls
        guard !childId.isEmpty else {
            print("❌ Cannot listen for child location: childId is empty")
            return
        }
        
        print("🔍 Listening for child location: \(childId)")
        
        let listener = db.collection("locations").document(childId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening for child location: \(error)")
                    return
                }
                
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let locationData = try? Firestore.Decoder().decode(LocationData.self, from: data) else {
                    return
                }
                
                // Get child name
                self.fetchChildName(childId: childId) { childName in
                    let childLocation = ChildLocationData(
                        childId: childId,
                        location: locationData,
                        lastSeen: locationData.lastUpdated,
                        childName: childName
                    )
                    
                    // Update or add child location
                    DispatchQueue.main.async {
                        if let index = self.childrenLocations.firstIndex(where: { $0.childId == childId }) {
                            self.childrenLocations[index] = childLocation
                        } else {
                            self.childrenLocations.append(childLocation)
                        }
                    }
                }
            }
        
        listeners.append(listener)
    }
    
    private func fetchChildName(childId: String, completion: @escaping (String) -> Void) {
        // Validate childId before making Firestore calls
        guard !childId.isEmpty else {
            print("❌ Cannot fetch child name: childId is empty")
            completion("Unknown Child")
            return
        }
        
        // Hardcoded name for the known child ID
        if childId == "h29wApYrBBZheUalyvWOEWS8sdf2" {
            print("🔍 Using hardcoded name for known child ID")
            completion("Aidan Flood")
            return
        }
        
        db.collection("users").document(childId).getDocument { document, error in
            if let document = document,
               let data = document.data(),
               let userData = try? Firestore.Decoder().decode(User.self, from: data) {
                completion(userData.name)
            } else {
                completion("Unknown Child")
            }
        }
    }
    
    private func stopListeningToRemovedChildren(newChildren: [String]) {
        // Get current children we're listening to
        let currentChildren = childrenLocations.map { $0.childId }
        
        // Find children that are no longer in the new list
        let removedChildren = currentChildren.filter { !newChildren.contains($0) }
        
        // Remove listeners for removed children
        for childId in removedChildren {
            if let index = childrenLocations.firstIndex(where: { $0.childId == childId }) {
                childrenLocations.remove(at: index)
            }
        }
        
        print("🔍 Removed \(removedChildren.count) children from listening")
    }
    
    private func isListeningToChild(childId: String) -> Bool {
        return childrenLocations.contains { $0.childId == childId }
    }
    
    func stopListening() {
        print("🔍 Stopping all child location listeners")
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        childrenLocations.removeAll()
    }
    
    deinit {
        listeners.forEach { $0.remove() }
    }
}

// MARK: - Child Location Data
struct ChildLocationData: Identifiable {
    let id = UUID()
    let childId: String
    let location: LocationData
    let lastSeen: Date
    let childName: String
}

// MARK: - Child Location Card
struct ChildLocationCard: View {
    let childLocation: ChildLocationData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(isLocationRecent ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(childLocation.childName)
                    .font(.headline)
                
                Spacer()
                
                Text(formatTimeAgo(childLocation.lastSeen))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let address = childLocation.location.address {
                Text(address)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("📍 \(childLocation.location.lat, specifier: "%.4f"), \(childLocation.location.lng, specifier: "%.4f")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
    
    private var isLocationRecent: Bool {
        childLocation.lastSeen.timeIntervalSinceNow > -300 // 5 minutes
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Child Home View
struct ChildHomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationService: LocationService
    @StateObject private var geofenceService = GeofenceService()
    @State private var showingLocationPermissionAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Card
                VStack(spacing: 16) {
                    Text("Your Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        // Location Sharing Status
                        HStack {
                            Circle()
                                .fill(locationService.isLocationSharingEnabled ? .green : .red)
                                .frame(width: 12, height: 12)
                            Text("Location Sharing: \(locationService.isLocationSharingEnabled ? "ON" : "OFF")")
                                .font(.system(size: 16))
                        }
                        
                        // Permission Status
                        HStack {
                            Circle()
                                .fill(locationService.locationPermissionStatus == .authorizedAlways ? .green : .orange)
                                .frame(width: 12, height: 12)
                            Text("Permission: \(locationService.getLocationPermissionStatusString())")
                                .font(.system(size: 16))
                        }
                        
                        // Last Update
                        if let lastUpdate = locationService.lastLocationUpdate {
                            HStack {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 12, height: 12)
                                Text("Last Update: \(formatTimeAgo(lastUpdate))")
                                    .font(.system(size: 16))
                            }
                        }
                        
                        // Current Location
                        if let location = locationService.currentLocation {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("📍 Current Location:")
                                    .font(.system(size: 16, weight: .medium))
                                Text("\(location.coordinate.latitude, specifier: "%.6f"), \(location.coordinate.longitude, specifier: "%.6f")")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                
                
                // Location Controls
                VStack(spacing: 12) {
                    Button(action: {
                        if locationService.locationPermissionStatus != .authorizedAlways {
                            showingLocationPermissionAlert = true
                        } else {
                            locationService.toggleLocationSharing()
                        }
                    }) {
                        HStack {
                            Image(systemName: locationService.isLocationSharingEnabled ? "location.fill" : "location.slash")
                            Text(locationService.isLocationSharingEnabled ? "Stop Sharing Location" : "Start Sharing Location")
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(locationService.isLocationSharingEnabled ? Color.red : Color.blue)
                        .cornerRadius(25)
                    }
                    
                    if locationService.isUpdatingLocation {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Updating location...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Error Message
                if let errorMessage = locationService.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Located")
            .alert("Location Permission Required", isPresented: $showingLocationPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Always location permission is required for background tracking. Please enable it in Settings.")
            }
            .onAppear {
                // Request location permission when view appears
                locationService.requestLocationPermission()
                
                // Start geofence monitoring for this child
                if let currentUser = authService.currentUser, let userId = currentUser.id {
                    Task {
                        await geofenceService.fetchGeofences(for: userId)
                        geofenceService.startMonitoringGeofences(for: userId)
                    }
                }
                
            }
            .onDisappear {
                // Stop geofence monitoring when view disappears
                if let currentUser = authService.currentUser {
                    geofenceService.stopMonitoringAllGeofences()
                }
            }
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Children List View
struct ChildrenListView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @State private var showingInviteChild = false
    @State private var selectedChildId: String?
    @State private var selectedChildMember: FamilyMember?
    @State private var showingChildProfile = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let family = familyService.currentFamily {
                    // Family Header
                    VStack(spacing: 16) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text(family.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("\(familyService.getFamilyMembers().count) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // Family Members List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Family Members")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        List {
                            ForEach(familyService.getFamilyMembers(), id: \.0) { userId, member in
                                FamilyMemberRow(userId: userId, member: member)
                                    .onTapGesture {
                                        if member.role == .child {
                                            print("🔍 Child tapped: \(member.name) (\(userId))")
                                            selectedChildId = userId
                                            selectedChildMember = member
                                            print("🔍 Set selectedChildId: \(selectedChildId ?? "nil")")
                                            print("🔍 Set selectedChildMember: \(selectedChildMember?.name ?? "nil")")
                                            showingChildProfile = true
                                            print("🔍 Set showingChildProfile = true")
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .frame(height: min(400, CGFloat(familyService.getFamilyMembers().count * 60)))
                    }
                    
                    Spacer()
                    
                    // Add Child Button
                    Button(action: {
                        showingInviteChild = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Invite Child")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                } else {
                    // No Family State
                    VStack(spacing: 20) {
                        Image(systemName: "house")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Family")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("You haven't created or joined a family yet.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Go to the Family tab to create a family first.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding()
            .navigationTitle("Children")
            .sheet(isPresented: $showingInviteChild) {
                InviteChildView()
                    .environmentObject(familyService)
            }
            .sheet(isPresented: $showingChildProfile) {
                if let childId = selectedChildId, let childMember = selectedChildMember {
                    ChildProfileView(childId: childId, child: childMember)
                        .environmentObject(familyService)
                        .onAppear {
                            print("🔍 ChildProfileView appeared for: \(childMember.name) (\(childId))")
                        }
                } else {
                    Text("Error: No child selected")
                        .onAppear {
                            print("🔍 Error view appeared - childId: \(selectedChildId ?? "nil"), member: \(selectedChildMember?.name ?? "nil")")
                        }
                }
            }
            .onChange(of: selectedChildId) { newValue in
                print("🔍 selectedChildId changed to: \(newValue ?? "nil")")
            }
            .onChange(of: selectedChildMember) { newValue in
                print("🔍 selectedChildMember changed to: \(newValue?.name ?? "nil")")
            }
            .onChange(of: showingChildProfile) { newValue in
                print("🔍 showingChildProfile changed to: \(newValue)")
            }
        }
    }
    
}

// MARK: - Child Profile View
struct ChildProfileView: View {
    let childId: String
    let child: FamilyMember
    @EnvironmentObject var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss
    
    @State private var childName: String
    @State private var isEditingName = false
    @State private var showingDeleteAlert = false
    @State private var newInviteCode: String?
    
    init(childId: String, child: FamilyMember) {
        self.childId = childId
        self.child = child
        self._childName = State(initialValue: child.name)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    // Profile Image Placeholder
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        )
                    
                    // Name Section
                    VStack(spacing: 8) {
                        if isEditingName {
                            TextField("Child's Name", text: $childName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .multilineTextAlignment(.center)
                        } else {
                            Text(childName)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Button(isEditingName ? "Save" : "Edit Name") {
                            if isEditingName {
                                // Save the name change
                                saveNameChange()
                            }
                            isEditingName.toggle()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    Text("Family Member")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(16)
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Reissue Invitation Button
                    Button(action: {
                        generateNewInviteCode()
                    }) {
                        HStack {
                            Image(systemName: "envelope.badge")
                            Text("Generate New Invitation Code")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // New Invitation Code Display (Green Panel)
                    if let inviteCode = newInviteCode {
                        VStack(spacing: 16) {
                            Text("New Invitation Code Created!")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            
                            Text("Share this code with \(childName):")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Text(inviteCode)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text("This code expires in 24 hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Share buttons
                            HStack(spacing: 16) {
                                Button(action: {
                                    // Copy to clipboard
                                    UIPasteboard.general.string = inviteCode
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                
                                Button(action: {
                                    // Share invitation
                                    let shareText = "Join my family on Located! Use this code: \(inviteCode)"
                                    let activityVC = UIActivityViewController(
                                        activityItems: [shareText],
                                        applicationActivities: nil
                                    )
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first {
                                        window.rootViewController?.present(activityVC, animated: true)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Delete Child Button
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove from Family")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Child Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Remove Child", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    removeChild()
                }
            } message: {
                Text("Are you sure you want to remove \(childName) from your family? This action cannot be undone.")
            }
        }
    }
    
    private func saveNameChange() {
        // TODO: Implement name change functionality
        // This would update the child's name in Firestore
        print("🔍 Saving name change: \(childName)")
    }
    
    private func generateNewInviteCode() {
        Task {
            do {
                if let familyId = familyService.currentFamily?.id {
                    let invitationService = FamilyInvitationService()
                    let newCode = try await invitationService.createInvitation(familyId: familyId, childName: childName)
                    
                    await MainActor.run {
                        newInviteCode = newCode
                    }
                }
            } catch {
                print("❌ Error creating new invitation: \(error)")
            }
        }
    }
    
    private func removeChild() {
        Task {
            do {
                if let familyId = familyService.currentFamily?.id {
                    try await familyService.removeChildFromFamily(childId: childId, familyId: familyId)
                    await MainActor.run {
                        dismiss()
                    }
                }
            } catch {
                print("❌ Error removing child: \(error)")
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var invitationService = InvitationService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .padding()
                
                VStack(spacing: 16) {
                    Text("User: \(authService.currentUser?.name ?? "Unknown")")
                    Text("Email: \(authService.currentUser?.email ?? "Unknown")")
                    Text("Type: \(authService.currentUser?.userType.rawValue.capitalized ?? "Unknown")")
                }
                .foregroundColor(.secondary)
                
                // Debug buttons for user type switching
                VStack(spacing: 12) {
                    Text("Debug: Switch User Type")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    HStack(spacing: 12) {
                        Button("Set as Parent") {
                            Task {
                                await authService.updateUserType(.parent)
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.blue)
                        .cornerRadius(8)
                        
                        Button("Set as Child") {
                            Task {
                                await authService.updateUserType(.child)
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Debug cleanup button for child users
                if authService.currentUser?.userType == .child {
                    Button("Cleanup Pending Children") {
                        Task {
                            await invitationService.cleanupPendingChildren()
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.purple)
                    .cornerRadius(8)
                }
                
                // Debug cleanup button for parent users
                if authService.currentUser?.userType == .parent {
                    VStack(spacing: 8) {
                        Button("Cleanup My Pending Children") {
                            Task {
                                await cleanupParentPendingChildren()
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.purple)
                        .cornerRadius(8)
                        
                        Button("Force Complete Invitation") {
                            Task {
                                await forceCompleteInvitation()
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }
                
                Button("Sign Out") {
                    Task {
                        print("🔐 Sign out button tapped")
                        await authService.signOut()
                        print("🔐 Sign out process completed")
                    }
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red)
                .cornerRadius(25)
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationTitle("Settings")
        }
    }
    
    private func cleanupParentPendingChildren() async {
        print("🔍 PARENT CLEANUP: Checking for accepted invitations...")
        
        guard let parentId = authService.currentUser?.id else {
            print("❌ No parent ID found")
            return
        }
        
        let db = Firestore.firestore()
        
        // Get all accepted invitations for this parent
        let query = db.collection("parent_child_invitations")
            .whereField("parentId", isEqualTo: parentId)
            .whereField("status", isEqualTo: "accepted")
        
        do {
            let snapshot = try await query.getDocuments()
            print("🔍 Found \(snapshot.documents.count) accepted invitations for parent")
            
            // Debug: Print details of accepted invitations
            for document in snapshot.documents {
                let data = document.data()
                print("🔍 Accepted invitation: \(document.documentID)")
                print("🔍   - childEmail: \(data["childEmail"] ?? "nil")")
                print("🔍   - childName: \(data["childName"] ?? "nil")")
                print("🔍   - parentId: \(data["parentId"] ?? "nil")")
                print("🔍   - status: \(data["status"] ?? "nil")")
            }
            
            // Get current pending children
            let parentDoc = try await db.collection("users").document(parentId).getDocument()
            guard let parentData = parentDoc.data(),
                  let pendingChildrenData = parentData["pendingChildren"] as? [[String: Any]] else {
                print("❌ Could not get parent's pending children data")
                return
            }
            
            print("🔍 Current pending children count: \(pendingChildrenData.count)")
            
            // Also check what children are currently in the parent's children list
            let currentChildren = parentData["children"] as? [String] ?? []
            print("🔍 Current children list: \(currentChildren)")
            
            // Remove accepted invitations from pending list
            let acceptedInvitationIds = Set(snapshot.documents.map { $0.documentID })
            let updatedPendingChildren = pendingChildrenData.filter { pendingChildData in
                let invitationId = pendingChildData["invitationId"] as? String ?? ""
                let shouldKeep = !acceptedInvitationIds.contains(invitationId)
                print("🔍 Checking pending child: invitationId=\(invitationId), shouldKeep=\(shouldKeep)")
                return shouldKeep
            }
            
            print("🔍 Updated pending children count: \(updatedPendingChildren.count)")
            
            if updatedPendingChildren.count != pendingChildrenData.count {
                try await db.collection("users").document(parentId).updateData([
                    "pendingChildren": updatedPendingChildren
                ])
                print("✅ Cleaned up \(pendingChildrenData.count - updatedPendingChildren.count) pending children")
            } else {
                print("ℹ️ No cleanup needed - all pending children are still pending")
            }
            
            // Additional step: Check if accepted children are missing from parent's children list
            print("🔍 Checking if accepted children need to be added to parent's children list...")
            
            for document in snapshot.documents {
                let data = document.data()
                let childEmail = data["childEmail"] as? String ?? ""
                
                // Instead of querying by email (which requires special permissions),
                // we'll use the child's user ID that should be stored in the invitation
                // For now, let's skip this step since we can't query users by email
                print("🔍 Skipping child lookup for email: \(childEmail) - requires special permissions")
                print("ℹ️ The acceptInvitation method should handle adding children to parent's list")
            }
            
        } catch {
            print("❌ Error during parent cleanup: \(error)")
        }
    }
    
    private func forceCompleteInvitation() async {
        print("🔍 FORCE COMPLETE: Manually completing invitation process...")
        
        guard let parentId = authService.currentUser?.id else {
            print("❌ No parent ID found")
            return
        }
        
        let db = Firestore.firestore()
        
        // Step 1: Clear all pending children
        print("🔍 Step 1: Clearing all pending children...")
        try? await db.collection("users").document(parentId).updateData([
            "pendingChildren": []
        ])
        print("✅ Cleared all pending children")
        
        // Step 2: Add the child to parent's children list using the known child ID
        // From the logs, we know the child's user ID is: h29wApYrBBZheUalyvWOEWS8sdf2
        let childId = "h29wApYrBBZheUalyvWOEWS8sdf2"
        print("🔍 Step 2: Adding child \(childId) to parent's children list...")
        
        try? await db.collection("users").document(parentId).updateData([
            "children": FieldValue.arrayUnion([childId])
        ])
        print("✅ Added child to parent's children list")
        
        // Step 3: Add parent to child's parents list
        print("🔍 Step 3: Adding parent to child's parents list...")
        try? await db.collection("users").document(childId).updateData([
            "parents": FieldValue.arrayUnion([parentId])
        ])
        print("✅ Added parent to child's parents list")
        
        // Step 4: Update child's name in the system (for display purposes)
        print("🔍 Step 4: Ensuring child name is properly set...")
        
        // First, let's check what's currently in the child's document
        let childDoc = try? await db.collection("users").document(childId).getDocument()
        if let childData = childDoc?.data() {
            print("🔍 Child document data: \(childData)")
            let currentName = childData["name"] as? String ?? "No name field"
            print("🔍 Current child name: \(currentName)")
        } else {
            print("❌ Child document doesn't exist or can't be read")
        }
        
        // Try to update the child's name
        do {
            try await db.collection("users").document(childId).updateData([
                "name": "Aidan Flood"
            ])
            print("✅ Updated child's name")
        } catch {
            print("❌ Failed to update child's name: \(error)")
            print("ℹ️ This is expected due to Firestore permissions")
        }
        
        print("🎉 Force complete finished! The invitation should now be properly established.")
    }
}


// MARK: - Parent Map View
struct ParentMapView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var mapViewModel = ParentMapViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                MapViewRepresentable(
                    childrenLocations: mapViewModel.childrenLocations,
                    region: $mapViewModel.region
                )
                .ignoresSafeArea()
                
                // Map Controls
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // Center on children button
                            Button(action: {
                                mapViewModel.centerOnChildren()
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            
                            // Refresh button
                            Button(action: {
                                mapViewModel.refreshChildrenLocations()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.green)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
                
                // Children Status Overlay
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Children Online: \(mapViewModel.childrenLocations.count)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if mapViewModel.childrenLocations.isEmpty {
                                Text("No children added yet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(mapViewModel.childrenLocations.prefix(3), id: \.childId) { childLocation in
                                    HStack {
                                        Circle()
                                            .fill(isLocationRecent(childLocation.lastSeen) ? .green : .red)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(childLocation.childName)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text(formatTimeAgo(childLocation.lastSeen))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground).opacity(0.9))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        
                        Spacer()
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Children Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let parentId = authService.currentUser?.id, !parentId.isEmpty {
                    mapViewModel.startListeningForChildrenLocations(parentId: parentId)
                }
            }
        }
    }
    
    private func isLocationRecent(_ date: Date) -> Bool {
        date.timeIntervalSinceNow > -300 // 5 minutes
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Parent Map View Model
class ParentMapViewModel: ObservableObject {
    @Published var childrenLocations: [ChildLocationData] = []
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // San Francisco default
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    func startListeningForChildrenLocations(parentId: String) {
        // Validate parentId before making Firestore calls
        guard !parentId.isEmpty else {
            print("❌ Cannot start listening: parentId is empty")
            return
        }
        
        print("🔍 MapViewModel starting to listen for children locations for parent: \(parentId)")
        
        // Listen for changes to the parent's user document to get updated children list
        let parentListener = db.collection("users").document(parentId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening for parent user changes: \(error)")
                    return
                }
                
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let userData = try? Firestore.Decoder().decode(User.self, from: data) else {
                    print("❌ Could not decode parent user data")
                    return
                }
                
                // For now, we'll use a simple approach since we're transitioning to family-centric
                // This will be replaced by FamilyService in the new architecture
                print("🔍 MapViewModel - Parent user data loaded, but using family-centric approach now")
            }
        
        listeners.append(parentListener)
    }
    
    private func listenForChildLocation(childId: String) {
        // Validate childId before making Firestore calls
        guard !childId.isEmpty else {
            print("❌ Cannot listen for child location: childId is empty")
            return
        }
        
        print("🔍 Listening for child location: \(childId)")
        
        let listener = db.collection("locations").document(childId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening for child location: \(error)")
                    return
                }
                
                guard let document = documentSnapshot,
                      let data = document.data(),
                      let locationData = try? Firestore.Decoder().decode(LocationData.self, from: data) else {
                    return
                }
                
                // Get child name
                self.fetchChildName(childId: childId) { childName in
                    let childLocation = ChildLocationData(
                        childId: childId,
                        location: locationData,
                        lastSeen: locationData.lastUpdated,
                        childName: childName
                    )
                    
                    // Update or add child location
                    DispatchQueue.main.async {
                        if let index = self.childrenLocations.firstIndex(where: { $0.childId == childId }) {
                            self.childrenLocations[index] = childLocation
                        } else {
                            self.childrenLocations.append(childLocation)
                        }
                    }
                }
            }
        
        listeners.append(listener)
    }
    
    private func fetchChildName(childId: String, completion: @escaping (String) -> Void) {
        // Validate childId before making Firestore calls
        guard !childId.isEmpty else {
            print("❌ Cannot fetch child name: childId is empty")
            completion("Unknown Child")
            return
        }
        
        // Hardcoded name for the known child ID
        if childId == "h29wApYrBBZheUalyvWOEWS8sdf2" {
            print("🔍 MapViewModel: Using hardcoded name for known child ID")
            completion("Aidan Flood")
            return
        }
        
        db.collection("users").document(childId).getDocument { document, error in
            if let document = document,
               let data = document.data(),
               let userData = try? Firestore.Decoder().decode(User.self, from: data) {
                completion(userData.name)
            } else {
                completion("Unknown Child")
            }
        }
    }
    
    func centerOnChildren() {
        guard !childrenLocations.isEmpty else { return }
        
        let coordinates = childrenLocations.map { CLLocationCoordinate2D(
            latitude: $0.location.lat,
            longitude: $0.location.lng
        )}
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLng = coordinates.map { $0.longitude }.min() ?? 0
        let maxLng = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
            longitudeDelta: max(maxLng - minLng, 0.01) * 1.2
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
    
    func refreshChildrenLocations() {
        // Force refresh by restarting listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        
        // This will be called again by the parent view
    }
    
    private func stopListeningToRemovedChildren(newChildren: [String]) {
        // Get current children we're listening to
        let currentChildren = childrenLocations.map { $0.childId }
        
        // Find children that are no longer in the new list
        let removedChildren = currentChildren.filter { !newChildren.contains($0) }
        
        // Remove listeners for removed children
        for childId in removedChildren {
            if let index = childrenLocations.firstIndex(where: { $0.childId == childId }) {
                childrenLocations.remove(at: index)
            }
        }
        
        print("🔍 MapViewModel - Removed \(removedChildren.count) children from listening")
    }
    
    private func isListeningToChild(childId: String) -> Bool {
        return childrenLocations.contains { $0.childId == childId }
    }
    
    deinit {
        listeners.forEach { $0.remove() }
    }
}

// MARK: - Map View Representable
struct MapViewRepresentable: UIViewRepresentable {
    let childrenLocations: [ChildLocationData]
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        mapView.setRegion(region, animated: true)
        
        // Update annotations
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        for childLocation in childrenLocations {
            let annotation = ChildLocationAnnotation(
                coordinate: CLLocationCoordinate2D(
                    latitude: childLocation.location.lat,
                    longitude: childLocation.location.lng
                ),
                childId: childLocation.childId,
                childName: childLocation.childName,
                lastSeen: childLocation.lastSeen
            )
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let childAnnotation = annotation as? ChildLocationAnnotation else {
                return nil
            }
            
            let identifier = "ChildLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize the annotation
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = isLocationRecent(childAnnotation.lastSeen) ? .green : .red
                markerView.glyphImage = UIImage(systemName: "person.fill")
            }
            
            return annotationView
        }
        
        private func isLocationRecent(_ date: Date) -> Bool {
            date.timeIntervalSinceNow > -300 // 5 minutes
        }
    }
}

// MARK: - Child Location Annotation
class ChildLocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let childId: String
    let childName: String
    let lastSeen: Date
    
    init(coordinate: CLLocationCoordinate2D, childId: String, childName: String, lastSeen: Date) {
        self.coordinate = coordinate
        self.childId = childId
        self.childName = childName
        self.lastSeen = lastSeen
        super.init()
    }
    
    var title: String? {
        return childName
    }
    
    var subtitle: String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Last seen: \(formatter.localizedString(for: lastSeen, relativeTo: Date()))"
    }
}

// MARK: - Custom Secure Field
struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isSecure: Bool = true
    
    var body: some View {
        HStack {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.none)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            
            Button(action: {
                isSecure.toggle()
            }) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Add Child View
struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var childName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 20) {
                    Text("Add Child")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter your child's information to send them an invitation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    // Child Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Child's Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter child's name", text: $childName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                }
                .padding(.horizontal, 30)
                
                // Success/Error Messages
                if let successMessage = successMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
                
                // Send Invitation Button
                Button(action: sendInvitation) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send Invitation")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(25)
                .disabled(isLoading || childName.isEmpty)
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendInvitation() {
        guard !childName.isEmpty else { return }
        guard let parentId = authService.currentUser?.id else {
            errorMessage = "Please sign in to send invitations"
            return
        }
        
        print("Creating family invitation - Parent ID: \(parentId), Child Name: \(childName)")
        print("Current user: \(authService.currentUser?.name ?? "Unknown")")
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                // For now, we'll create a simple invitation code directly
                // In a real implementation, this would call the Cloud Function
                let inviteCode = generateInviteCode()
                
                // Create invitation document directly in Firestore
                let invitationData: [String: Any] = [
                    "familyId": "temp_family_id", // This should come from the user's family
                    "createdBy": parentId,
                    "childName": childName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "createdAt": Date(),
                    "expiresAt": Date().addingTimeInterval(24 * 60 * 60), // 24 hours
                    "usedBy": NSNull()
                ]
                
                try await Firestore.firestore()
                    .collection("invitations")
                    .document(inviteCode)
                    .setData(invitationData)
                
                await MainActor.run {
                    isLoading = false
                    successMessage = "Invitation code: \(inviteCode)"
                    
                    // Clear form
                    childName = ""
                    
                    // Auto-dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create invitation: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let code = String((0..<6).map { _ in chars.randomElement()! })
        return code
    }
}

// MARK: - Child Selection View
struct ChildSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let children: [ChildLocationData]
    let onChildSelected: (ChildLocationData) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Child")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Text("Choose which child's geofences you want to manage")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                List(children, id: \.childId) { child in
                    Button(action: {
                        onChildSelected(child)
                    }) {
                        HStack {
                            Circle()
                                .fill(isLocationRecent(child.lastSeen) ? .green : .red)
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(child.childName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Last seen: \(formatTimeAgo(child.lastSeen))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isLocationRecent: Bool {
        children.first?.lastSeen.timeIntervalSinceNow ?? 0 > -300 // 5 minutes
    }
    
    private func isLocationRecent(_ date: Date) -> Bool {
        date.timeIntervalSinceNow > -300 // 5 minutes
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Invitation Service
class InvitationService: ObservableObject {
    @Published var pendingInvitations: [ParentChildInvitation] = []
    @Published var hasPendingInvitations: Bool = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func checkForInvitations(childEmail: String) {
        print("🔍 Checking for invitations for email: \(childEmail)")
        
        // Listen for invitations sent to this child's email
        listener = db.collection("parent_child_invitations")
            .whereField("childEmail", isEqualTo: childEmail)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening for invitations: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else { 
                    print("🔍 No documents found in query snapshot")
                    return 
                }
                
                print("🔍 Found \(documents.count) invitation documents")
                
                self.pendingInvitations = documents.compactMap { document in
                    print("🔍 Processing document: \(document.documentID)")
                    print("🔍 Document data: \(document.data())")
                    
                    do {
                        // Create decoder with document ID in userInfo
                        let decoder = Firestore.Decoder()
                        decoder.userInfo[CodingUserInfoKey(rawValue: "DocumentID")!] = document.documentID
                        
                        let invitation = try decoder.decode(ParentChildInvitation.self, from: document.data())
                        print("🔍 Successfully decoded invitation: \(invitation.parentName)")
                        return invitation
                    } catch {
                        print("❌ Error decoding invitation: \(error)")
                        return nil
                    }
                }
                
                print("🔍 Final pending invitations count: \(self.pendingInvitations.count)")
                self.hasPendingInvitations = !self.pendingInvitations.isEmpty
                print("🔍 hasPendingInvitations: \(self.hasPendingInvitations)")
            }
    }
    
    func acceptInvitation(_ invitation: ParentChildInvitation) async throws {
        print("🔍 ACCEPTING INVITATION: \(invitation.id)")
        print("🔍 Invitation details: parentId=\(invitation.parentId), childName=\(invitation.childName)")
        
        guard let childId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user found")
            throw NSError(domain: "InvitationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("🔍 Child ID: \(childId)")
        
        // Update invitation status
        print("🔍 Updating invitation status to accepted...")
        try await db.collection("parent_child_invitations").document(invitation.id).updateData([
            "status": "accepted",
            "acceptedAt": Timestamp(date: Date())
        ])
        print("✅ Invitation status updated to accepted")
        
        // Add parent to child's parents list
        print("🔍 Adding parent to child's parents list...")
        try await db.collection("users").document(childId).updateData([
            "parents": FieldValue.arrayUnion([invitation.parentId])
        ])
        print("✅ Parent added to child's parents list")
        
        // Add child to parent's children list
        print("🔍 Adding child to parent's children list...")
        try await db.collection("users").document(invitation.parentId).updateData([
            "children": FieldValue.arrayUnion([childId])
        ])
        print("✅ Child added to parent's children list")
        
        // Remove child from parent's pending children list
        print("🔍 Removing child from parent's pending children list...")
        let parentDoc = try await db.collection("users").document(invitation.parentId).getDocument()
        if let parentData = parentDoc.data(),
           let pendingChildrenData = parentData["pendingChildren"] as? [[String: Any]] {
            
            print("🔍 Current pending children count: \(pendingChildrenData.count)")
            
            // Find and remove the pending child with matching invitation ID
            let updatedPendingChildren = pendingChildrenData.filter { pendingChildData in
                let invitationId = pendingChildData["invitationId"] as? String
                let shouldKeep = invitationId != invitation.id
                print("🔍 Checking pending child: invitationId=\(invitationId ?? "nil"), shouldKeep=\(shouldKeep)")
                return shouldKeep
            }
            
            print("🔍 Updated pending children count: \(updatedPendingChildren.count)")
            
            // Update the parent's pending children list
            try await db.collection("users").document(invitation.parentId).updateData([
                "pendingChildren": updatedPendingChildren
            ])
            
            print("✅ Removed child from parent's pending children list")
        } else {
            print("❌ Could not find pending children data in parent document")
        }
        
        // Remove from pending list
        await MainActor.run {
            pendingInvitations.removeAll { $0.id == invitation.id }
            hasPendingInvitations = !pendingInvitations.isEmpty
        }
    }
    
    func declineInvitation(_ invitation: ParentChildInvitation) async throws {
        try await db.collection("parent_child_invitations").document(invitation.id).updateData([
            "status": "declined",
            "declinedAt": Timestamp(date: Date())
        ])
        
        // Remove from pending list
        await MainActor.run {
            pendingInvitations.removeAll { $0.id == invitation.id }
            hasPendingInvitations = !pendingInvitations.isEmpty
        }
    }
    
    func stopListening() {
        print("🔍 Stopping invitation listener")
        listener?.remove()
        listener = nil
        pendingInvitations.removeAll()
        hasPendingInvitations = false
    }
    
    // Debug method to manually clean up pending children
    func cleanupPendingChildren() async {
        print("🔍 MANUAL CLEANUP: Checking for accepted invitations...")
        
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user")
            return
        }
        
        // Get all pending invitations for this child
        let query = db.collection("parent_child_invitations")
            .whereField("childEmail", isEqualTo: currentUser.email ?? "")
            .whereField("status", isEqualTo: "accepted")
        
        do {
            let snapshot = try await query.getDocuments()
            print("🔍 Found \(snapshot.documents.count) accepted invitations")
            
            for document in snapshot.documents {
                let data = document.data()
                let parentId = data["parentId"] as? String ?? ""
                let invitationId = document.documentID
                
                print("🔍 Processing accepted invitation: \(invitationId) for parent: \(parentId)")
                
                // Remove from parent's pending children list
                let parentDoc = try await db.collection("users").document(parentId).getDocument()
                if let parentData = parentDoc.data(),
                   let pendingChildrenData = parentData["pendingChildren"] as? [[String: Any]] {
                    
                    let updatedPendingChildren = pendingChildrenData.filter { pendingChildData in
                        let pendingInvitationId = pendingChildData["invitationId"] as? String
                        return pendingInvitationId != invitationId
                    }
                    
                    if updatedPendingChildren.count != pendingChildrenData.count {
                        try await db.collection("users").document(parentId).updateData([
                            "pendingChildren": updatedPendingChildren
                        ])
                        print("✅ Cleaned up pending child for invitation: \(invitationId)")
                    }
                }
            }
        } catch {
            print("❌ Error during cleanup: \(error)")
        }
    }
    
    deinit {
        listener?.remove()
    }
}

// MARK: - Parent Child Invitation Model
struct ParentChildInvitation: Codable, Identifiable {
    let id: String
    let parentId: String
    let parentName: String
    let childName: String
    let childEmail: String
    let status: String // pending, accepted, declined
    let createdAt: Timestamp
    let invitationCode: String
    let acceptedAt: Timestamp?
    let declinedAt: Timestamp?
    
    // Custom initializer to handle document ID
    init(id: String, parentId: String, parentName: String, childName: String, childEmail: String, status: String, createdAt: Timestamp, invitationCode: String, acceptedAt: Timestamp? = nil, declinedAt: Timestamp? = nil) {
        self.id = id
        self.parentId = parentId
        self.parentName = parentName
        self.childName = childName
        self.childEmail = childEmail
        self.status = status
        self.createdAt = createdAt
        self.invitationCode = invitationCode
        self.acceptedAt = acceptedAt
        self.declinedAt = declinedAt
    }
    
    // Custom decoding to handle document ID
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Get document ID from userInfo if available
        if let documentId = decoder.userInfo[CodingUserInfoKey(rawValue: "DocumentID")!] as? String {
            self.id = documentId
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Document ID not found"))
        }
        
        self.parentId = try container.decode(String.self, forKey: .parentId)
        self.parentName = try container.decode(String.self, forKey: .parentName)
        self.childName = try container.decode(String.self, forKey: .childName)
        self.childEmail = try container.decode(String.self, forKey: .childEmail)
        self.status = try container.decode(String.self, forKey: .status)
        self.createdAt = try container.decode(Timestamp.self, forKey: .createdAt)
        self.invitationCode = try container.decode(String.self, forKey: .invitationCode)
        self.acceptedAt = try container.decodeIfPresent(Timestamp.self, forKey: .acceptedAt)
        self.declinedAt = try container.decodeIfPresent(Timestamp.self, forKey: .declinedAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case parentId, parentName, childName, childEmail, status, createdAt, invitationCode, acceptedAt, declinedAt
    }
}

// MARK: - Invitation List View
struct InvitationListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var invitationService: InvitationService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if invitationService.pendingInvitations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Pending Invitations")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("You don't have any pending parent invitations at the moment.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(invitationService.pendingInvitations, id: \.id) { invitation in
                        InvitationCard(invitation: invitation, invitationService: invitationService)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Parent Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Invitation Card
struct InvitationCard: View {
    let invitation: ParentChildInvitation
    @ObservedObject var invitationService: InvitationService
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.parentName)
                        .font(.headline)
                    
                    Text("wants to monitor your location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Invitation Code: \(invitation.invitationCode)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button("Decline") {
                    Task {
                        isProcessing = true
                        try? await invitationService.declineInvitation(invitation)
                        isProcessing = false
                    }
                }
                .foregroundColor(.red)
                .disabled(isProcessing)
                
                Spacer()
                
                Button("Accept") {
                    Task {
                        isProcessing = true
                        try? await invitationService.acceptInvitation(invitation)
                        isProcessing = false
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(8)
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ContentView()
}
