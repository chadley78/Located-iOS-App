import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit
import MapKit

struct ContentView: View {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(authService)
                    .environmentObject(locationService)
            } else {
                WelcomeView()
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
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingSignIn = false
    
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
                    NavigationLink(destination: AuthenticationView(userType: .parent)) {
                        Text("I'm a Parent")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                    
                    NavigationLink(destination: AuthenticationView(userType: .child)) {
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
                
                // Sign In Link
                VStack(spacing: 8) {
                    Text("Already have an account?")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Button("Sign In") {
                        showingSignIn = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSignIn) {
                SignInView()
                    .environmentObject(authService)
            }
        }
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    let userType: User.UserType
    @EnvironmentObject var authService: AuthenticationService
    @State private var isSignUp = false
    
    var body: some View {
        VStack(spacing: 20) {
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(userType == .parent ? "Parent Login" : "Child Login")
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
                let _ = print("🔍 MainTabView: Showing PARENT UI for user: \(authService.currentUser?.name ?? "Unknown")")
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
    @StateObject private var childLocationService = ChildLocationService()
    @StateObject private var geofenceService = GeofenceService()
    
    @State private var selectedChildForGeofences: ChildLocationData?
    @State private var showingGeofenceManagement = false
    @State private var showingAddChild = false
    @State private var showingChildSelection = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Children Status Overview
                VStack(spacing: 16) {
                    Text("Children Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if childLocationService.childrenLocations.isEmpty && childLocationService.pendingChildren.isEmpty {
                        Text("No children added yet")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        // Show active children
                        ForEach(childLocationService.childrenLocations, id: \.childId) { childLocation in
                            ChildLocationCard(childLocation: childLocation)
                        }
                        
                        // Show pending children
                        ForEach(childLocationService.pendingChildren, id: \.id) { pendingChild in
                            PendingChildCard(pendingChild: pendingChild)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                
                // Quick Actions
                VStack(spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingAddChild = true
                        }) {
                            VStack {
                                Image(systemName: "person.badge.plus")
                                    .font(.title2)
                                Text("Add Child")
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        NavigationLink(destination: ParentMapView()) {
                            VStack {
                                Image(systemName: "map")
                                    .font(.title2)
                                Text("View Map")
                                    .font(.caption)
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            if childLocationService.childrenLocations.isEmpty {
                                // If no children, show add child prompt
                                showingAddChild = true
                            } else if childLocationService.childrenLocations.count == 1 {
                                // If only one child, go directly to their geofences
                                selectedChildForGeofences = childLocationService.childrenLocations.first
                                showingGeofenceManagement = true
                            } else {
                                // If multiple children, show selection
                                showingChildSelection = true
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
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Located")
            .onAppear {
                if let parentId = authService.currentUser?.id, !parentId.isEmpty {
                    childLocationService.startListeningForChildrenLocations(parentId: parentId)
                }
            }
            .onDisappear {
                // Clean up services when view disappears
                childLocationService.stopListening()
                geofenceService.stopMonitoringAllGeofences()
            }
            .sheet(isPresented: $showingGeofenceManagement) {
                if let selectedChild = selectedChildForGeofences {
                    GeofenceManagementView(
                        childId: selectedChild.childId,
                        childName: selectedChild.childName
                    )
                }
            }
            .sheet(isPresented: $showingAddChild) {
                AddChildView()
            }
            .sheet(isPresented: $showingChildSelection) {
                ChildSelectionView(
                    children: childLocationService.childrenLocations,
                    onChildSelected: { child in
                        selectedChildForGeofences = child
                        showingGeofenceManagement = true
                        showingChildSelection = false
                    }
                )
            }
        }
    }
}

// MARK: - Child Location Service
class ChildLocationService: ObservableObject {
    @Published var childrenLocations: [ChildLocationData] = []
    @Published var pendingChildren: [PendingChild] = []
    
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
                
                let newChildren = userData.children
                let newPendingChildren = userData.pendingChildren ?? []
                
                print("🔍 Parent has \(newChildren.count) children: \(newChildren)")
                print("🔍 Parent has \(newPendingChildren.count) pending children: \(newPendingChildren.map { $0.name })")
                
                // Update pending children
                self.pendingChildren = newPendingChildren
                
                // Stop listening to old children that are no longer in the list
                self.stopListeningToRemovedChildren(newChildren: newChildren)
                
                // Start listening to new children
                for childId in newChildren {
                    if !self.isListeningToChild(childId: childId) {
                        self.listenForChildLocation(childId: childId)
                    }
                }
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

// MARK: - Pending Child Card
struct PendingChildCard: View {
    let pendingChild: PendingChild
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(.orange)
                    .frame(width: 12, height: 12)
                
                Text(pendingChild.name)
                    .font(.headline)
                
                Spacer()
                
                Text("PENDING")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            Text("Email: \(pendingChild.email)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Invitation Code: \(pendingChild.invitationCode)")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            
            Text("Sent: \(formatTimeAgo(pendingChild.createdAt))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
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
    @State private var showingInvitations = false
    @StateObject private var invitationService = InvitationService()
    
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
                        
                        // Parents Monitoring
                        Text("👨‍👩‍👧‍👦 Parents Monitoring: \(authService.currentUser?.parents.count ?? 0)")
                            .font(.system(size: 16))
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                
                // Invitation Notification
                if invitationService.hasPendingInvitations {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "envelope.badge")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("New Parent Invitation")
                                    .font(.headline)
                                Text("You have \(invitationService.pendingInvitations.count) pending invitation(s)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("View") {
                                showingInvitations = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .onAppear {
                        print("🔍 Invitation notification card is now visible")
                    }
                } else {
                    // Debug: Show why notification card is not appearing
                    VStack {
                        Text("Debug: hasPendingInvitations = \(invitationService.hasPendingInvitations)")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Pending count = \(invitationService.pendingInvitations.count)")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Button("Test Check Invitations") {
                            let childEmail = authService.currentUser?.email ?? ""
                            print("🔍 Manual test - checking invitations for: \(childEmail)")
                            invitationService.checkForInvitations(childEmail: childEmail)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .onAppear {
                        print("🔍 Invitation notification card is NOT visible")
                        print("🔍 hasPendingInvitations: \(invitationService.hasPendingInvitations)")
                        print("🔍 pendingInvitations.count: \(invitationService.pendingInvitations.count)")
                    }
                }
                
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
                
                // Check for pending invitations
                let childEmail = authService.currentUser?.email ?? ""
                print("🔍 ChildHomeView onAppear - checking invitations for: \(childEmail)")
                invitationService.checkForInvitations(childEmail: childEmail)
            }
            .onDisappear {
                // Stop geofence monitoring when view disappears
                if let currentUser = authService.currentUser {
                    geofenceService.stopMonitoringAllGeofences()
                }
                // Clean up invitation service
                invitationService.stopListening()
            }
            .sheet(isPresented: $showingInvitations) {
                InvitationListView(invitationService: invitationService)
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
    var body: some View {
        NavigationView {
            VStack {
                Text("Children List")
                    .font(.largeTitle)
                    .padding()
                
                Text("Children management will be implemented later")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Children")
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
                
                let newChildren = userData.children
                print("🔍 MapViewModel - Parent has \(newChildren.count) children: \(newChildren)")
                
                // Stop listening to old children that are no longer in the list
                self.stopListeningToRemovedChildren(newChildren: newChildren)
                
                // Start listening to new children
                for childId in newChildren {
                    if !self.isListeningToChild(childId: childId) {
                        self.listenForChildLocation(childId: childId)
                    }
                }
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
    
    @State private var childEmail = ""
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
                    
                    // Child Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Child's Email")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter child's email", text: $childEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
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
                .disabled(isLoading || childName.isEmpty || childEmail.isEmpty)
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
        guard !childName.isEmpty && !childEmail.isEmpty else { return }
        guard let parentId = authService.currentUser?.id else {
            errorMessage = "Please sign in to send invitations"
            return
        }
        
        print("Sending invitation - Parent ID: \(parentId), Child Name: \(childName), Child Email: \(childEmail)")
        print("Current user: \(authService.currentUser?.name ?? "Unknown")")
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await createParentChildInvitation(
                    parentId: parentId,
                    childName: childName,
                    childEmail: childEmail
                )
                
                await MainActor.run {
                    isLoading = false
                    successMessage = "Invitation sent to \(childEmail)!"
                    
                    // Clear form
                    childName = ""
                    childEmail = ""
                    
                    // Auto-dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to send invitation: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func createParentChildInvitation(parentId: String, childName: String, childEmail: String) async throws {
        let db = Firestore.firestore()
        
        // Validate inputs
        guard !parentId.isEmpty, !childName.isEmpty, !childEmail.isEmpty else {
            throw NSError(domain: "InvitationService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing required fields: parentId, childName, or childEmail"])
        }
        
        // Create invitation document
        let invitationData: [String: Any] = [
            "parentId": parentId,
            "parentName": authService.currentUser?.name ?? "Unknown Parent",
            "childName": childName,
            "childEmail": childEmail,
            "status": "pending", // pending, accepted, declined
            "createdAt": Timestamp(date: Date()),
            "invitationCode": generateInvitationCode()
        ]
        
        print("Creating invitation with data: \(invitationData)")
        
        do {
            let docRef = try await db.collection("parent_child_invitations").addDocument(data: invitationData)
            print("Invitation created successfully with ID: \(docRef.documentID)")
            
            // Add child to parent's pending children list
            let pendingChild = PendingChild(
                id: UUID().uuidString,
                name: childName,
                email: childEmail,
                invitationCode: invitationData["invitationCode"] as! String,
                invitationId: docRef.documentID
            )
            
            // Get current pending children and add the new one
            let parentDoc = try await db.collection("users").document(parentId).getDocument()
            var currentPendingChildren: [[String: Any]] = []
            
            if let parentData = parentDoc.data(),
               let existingPendingChildren = parentData["pendingChildren"] as? [[String: Any]] {
                currentPendingChildren = existingPendingChildren
            }
            
            // Add the new pending child
            currentPendingChildren.append(try Firestore.Encoder().encode(pendingChild) as! [String: Any])
            
            try await db.collection("users").document(parentId).updateData([
                "pendingChildren": currentPendingChildren
            ])
            
            print("Added child to parent's pending children list")
            
        } catch {
            print("Error creating invitation: \(error)")
            throw error
        }
    }
    
    private func generateInvitationCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
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
