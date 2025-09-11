import SwiftUI
import FirebaseAuth

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
                    
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Confirm Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Children Status Overview
                VStack(spacing: 16) {
                    Text("Children Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if childLocationService.childrenLocations.isEmpty {
                        Text("No children added yet")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(childLocationService.childrenLocations, id: \.childId) { childLocation in
                            ChildLocationCard(childLocation: childLocation)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Quick Actions
                VStack(spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            // Add child action
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
                        
                        Button(action: {
                            // View map action
                        }) {
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
                            // Settings action
                        }) {
                            VStack {
                                Image(systemName: "geofence")
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
                childLocationService.startListeningForChildrenLocations(parentId: authService.currentUser?.id ?? "")
            }
        }
    }
}

// MARK: - Child Location Service
class ChildLocationService: ObservableObject {
    @Published var childrenLocations: [ChildLocationData] = []
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    func startListeningForChildrenLocations(parentId: String) {
        // Get children from user profile
        db.collection("users").document(parentId).getDocument { [weak self] document, error in
            guard let self = self,
                  let document = document,
                  let userData = try? document.data(as: User.self),
                  let children = userData.children else {
                return
            }
            
            // Listen for location updates for each child
            for childId in children {
                self.listenForChildLocation(childId: childId)
            }
        }
    }
    
    private func listenForChildLocation(childId: String) {
        let listener = db.collection("locations").document(childId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening for child location: \(error)")
                    return
                }
                
                guard let document = documentSnapshot,
                      let locationData = try? document.data(as: LocationData.self) else {
                    return
                }
                
                let childLocation = ChildLocationData(
                    childId: childId,
                    location: locationData,
                    lastSeen: locationData.lastUpdated
                )
                
                // Update or add child location
                if let index = self.childrenLocations.firstIndex(where: { $0.childId == childId }) {
                    self.childrenLocations[index] = childLocation
                } else {
                    self.childrenLocations.append(childLocation)
                }
            }
        
        listeners.append(listener)
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
}

// MARK: - Child Location Card
struct ChildLocationCard: View {
    let childLocation: ChildLocationData
    @State private var childName: String = "Loading..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(isLocationRecent ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(childName)
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
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onAppear {
            fetchChildName()
        }
    }
    
    private var isLocationRecent: Bool {
        childLocation.lastSeen.timeIntervalSinceNow > -300 // 5 minutes
    }
    
    private func fetchChildName() {
        Firestore.firestore().collection("users").document(childLocation.childId).getDocument { document, error in
            if let document = document,
               let userData = try? document.data(as: User.self) {
                childName = userData.name
            }
        }
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
                        
                        // Parents Monitoring
                        Text("👨‍👩‍👧‍👦 Parents Monitoring: \(authService.currentUser?.parents.count ?? 0)")
                            .font(.system(size: 16))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
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
                
                Button("Sign Out") {
                    Task {
                        await authService.signOut()
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

#Preview {
    ContentView()
}