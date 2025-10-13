import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit
import MapKit
import PhotosUI
import Combine

struct ContentView: View {
    let invitationCode: String?
    @StateObject private var authService = AuthenticationService()
    @StateObject private var locationService = LocationService()
    @StateObject private var invitationService = FamilyInvitationService()
    @EnvironmentObject var familyService: FamilyService
    @State private var showContent = false
    
    init(invitationCode: String? = nil) {
        self.invitationCode = invitationCode
    }
    
    var body: some View {
        Group {
            if !showContent {
                // Show launch screen while transitioning
                Color.vibrantYellow
                    .ignoresSafeArea()
            } else if authService.isInitializing {
                // Show loading screen while checking authentication state
                VStack(spacing: 20) {
                    Circle()
                        .fill(Color.vibrantYellow)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image("AppSplash")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        )
                    
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.vibrantYellow)
            } else if authService.isAuthenticated {
                if authService.currentUser != nil {
                    MainTabView()
                        .environmentObject(authService)
                        .environmentObject(locationService)
                        .environmentObject(familyService)
                        .environmentObject(invitationService)
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
                    .background(Color.vibrantYellow)
                }
            } else {
                WelcomeView(invitationCode: invitationCode)
                    .environmentObject(authService)
                    .environmentObject(familyService)
                    .environmentObject(locationService)
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .onAppear {
            // Delay content display to allow launch screen to show
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
            
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
    @EnvironmentObject var familyService: FamilyService
    @EnvironmentObject var locationService: LocationService
    
    init(invitationCode: String? = nil) {
        self.invitationCode = invitationCode
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo and Title
                VStack(spacing: 20) {
                    Text("Located")
                        .font(.radioCanadaBig(40, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // Parrot image full bleed
                    Image("Parrot")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, -16)
                    
                    VStack(spacing: 2) {
                        Text("Providing a parents")
                            .font(.radioCanadaBig(18, weight: .regular))
                            .foregroundColor(.black)
                            .tracking(-0.9) // 5% of 18pt = 0.9pt reduction
                        Text("view of the world")
                            .font(.radioCanadaBig(18, weight: .regular))
                            .foregroundColor(.black)
                            .tracking(-0.9) // 5% of 18pt = 0.9pt reduction
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Role Selection Buttons
                VStack(spacing: 16) {
                    NavigationLink(destination: AuthenticationView(userType: .parent, invitationCode: invitationCode)
                        .environmentObject(authService)
                        .environmentObject(familyService)
                        .environmentObject(locationService)) {
                        Text("I'm a Parent")
                    }
                    .primaryAButtonStyle()
                    
                    NavigationLink(destination: AuthenticationView(userType: .child, invitationCode: invitationCode)
                        .environmentObject(authService)
                        .environmentObject(familyService)
                        .environmentObject(locationService)) {
                        Text("I'm a Child")
                    }
                    .primaryAButtonStyle()
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .background(Color.vibrantYellow)
        }
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    let userType: User.UserType
    let invitationCode: String?
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @EnvironmentObject var locationService: LocationService
    @State private var isSignUp = false
    
    var body: some View {
        VStack(spacing: 20) {
            if userType == .child {
                // Child-specific flow
                ChildSignUpView(invitationCode: invitationCode)
                    .environmentObject(authService)
                    .environmentObject(familyService)
                    .environmentObject(locationService)
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
    @EnvironmentObject var locationService: LocationService
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
                        // Request Always permission and trigger background location
                        locationService.requestAlwaysPermissionAndStartBackground()
                        // Force location update so parent map shows child immediately
                        locationService.forceLocationUpdate()
                        // Complete the welcome flow and show main view
                        authService.completeWelcomeFlow()
                    }
                } else {
                    ChildWelcomeView {
                        // Request Always permission and trigger background location
                        locationService.requestAlwaysPermissionAndStartBackground()
                        // Force location update so parent map shows child immediately
                        locationService.forceLocationUpdate()
                        // Complete the welcome flow and show main view
                        authService.completeWelcomeFlow()
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                    Spacer()
                    
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Join Your Family")
                            .font(.title)
                            .font(.system(size: 28, weight: .bold))
                        
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
                }
            }
            .primaryAButtonStyle()
            .disabled(!isFormValid || isLoading)
            
                    Spacer()
                    }
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
                
                // Create user profile with temporary name (will be updated after invitation acceptance)
                let newUser = User(
                    id: authResult.user.uid,
                    name: "Child", // Temporary name, will be updated from invitation
                    email: tempEmail,
                    userType: .child
                )
                
                print("🔍 Created child user object with temporary name: \(newUser.name)")
                
                // Save user profile to Firestore
                try await authService.saveUserProfile(newUser)
                print("🔍 Saved child user profile to Firestore")
                
                // Now accept the invitation (user is now authenticated)
                let invitationResult = try await invitationService.acceptInvitation(inviteCode: trimmedCode)
                print("🔍 Invitation accepted successfully")
                
                // Get child name from invitation result
                let childName = invitationResult["childName"] as? String ?? "Child"
                
                // Update the user's display name with the correct name from invitation
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = childName
                try await changeRequest.commitChanges()
                
                // The Cloud Function will update the user document with familyId
                // We just need to wait for it to complete and then refresh our local profile
                print("🔍 Cloud Function completed, now setting up account...")
                
                // Add a short delay to ensure Firestore write is visible
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Force refresh the user profile to get the latest data from Firestore
                // This will include the familyId that the Cloud Function added
                await authService.refreshUserProfile()
                print("🔍 Refreshed user profile after Cloud Function completion")
                
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
    
}

// MARK: - Sign In View
struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingForgotPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Address")
                            .font(.radioCanadaBig(14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .email)
                            .onSubmit {
                                focusedField = .password
                            }
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.radioCanadaBig(14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                signIn()
                            }
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
                    }
                }
                .primaryAButtonStyle()
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                
                // Forgot Password
                Button("Forgot Password?") {
                    showingForgotPassword = true
                }
                .font(.system(size: 16))
                .foregroundColor(.blue)
                
                Spacer()
                }
            }
            .onAppear {
                // Set initial focus to email field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusedField = .email
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

// MARK: - Password Strength View
struct PasswordStrengthView: View {
    let password: String
    
    private var strength: PasswordStrength {
        calculateStrength(password)
    }
    
    var body: some View {
        if !password.isEmpty {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<4) { index in
                        Rectangle()
                            .fill(strength.color.opacity(index < strength.score ? 1 : 0.2))
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                
                Text(strength.text)
                    .font(.caption)
                    .foregroundColor(strength.color)
            }
        }
    }
    
    private func calculateStrength(_ password: String) -> PasswordStrength {
        var score = 0
        
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isUppercase }) && password.contains(where: { $0.isLowercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) && password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) { score += 1 }
        
        switch score {
        case 0...1:
            return PasswordStrength(score: score, text: "Weak", color: .red)
        case 2:
            return PasswordStrength(score: score, text: "Fair", color: .orange)
        case 3:
            return PasswordStrength(score: score, text: "Good", color: .yellow)
        case 4:
            return PasswordStrength(score: score, text: "Strong", color: .green)
        default:
            return PasswordStrength(score: 0, text: "Weak", color: .red)
        }
    }
}

struct PasswordStrength {
    let score: Int
    let text: String
    let color: Color
}

// MARK: - Validation States
enum ValidationState {
    case none
    case valid
    case invalid(String) // Contains error message
    
    var isValid: Bool {
        switch self {
        case .valid: return true
        case .none, .invalid: return false
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
    @State private var emailValidationState: ValidationState = .none
    @State private var passwordValidationState: ValidationState = .none
    @State private var confirmPasswordValidationState: ValidationState = .none
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, password, confirmPassword
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                // Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name")
                        .font(.radioCanadaBig(14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Enter your name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($focusedField, equals: .name)
                            .onSubmit {
                                focusedField = .email
                            }
                        
                        // Spacer to maintain consistent width
                        Spacer()
                            .frame(width: 24) // Same width as validation indicator
                    }
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.radioCanadaBig(14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.emailAddress)
                            .accessibilityLabel("Email address")
                            .focused($focusedField, equals: .email)
                            .onSubmit {
                                focusedField = .password
                            }
                            .onChange(of: email) { _ in
                                validateEmail()
                            }
                        
                        // Validation indicator
                        Image(systemName: emailValidationState.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor({
                                switch emailValidationState {
                                case .none: return .clear
                                case .valid: return .green
                                case .invalid: return .red
                                }
                            }())
                            .font(.system(size: 16))
                    }
                    
                    // Validation error message
                    if case .invalid(let message) = emailValidationState {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.radioCanadaBig(14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack {
                        CustomSecureField(placeholder: "Enter your password", text: $password)
                            .textContentType(.newPassword)
                            .accessibilityLabel("New password")
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                focusedField = .confirmPassword
                            }
                            .onChange(of: password) { _ in
                                validatePassword()
                                validateConfirmPassword()
                            }
                        
                        // Spacer to maintain consistent width
                        Spacer()
                            .frame(width: 24) // Same width as validation indicator
                    }
                    
                    // Password strength indicator
                    PasswordStrengthView(password: password)
                    
                    // Validation error message
                    if case .invalid(let message) = passwordValidationState {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Confirm Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.radioCanadaBig(14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack {
                        CustomSecureField(placeholder: "Confirm your password", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .accessibilityLabel("Confirm password")
                            .focused($focusedField, equals: .confirmPassword)
                            .onSubmit {
                                signUp()
                            }
                            .onChange(of: confirmPassword) { _ in
                                validateConfirmPassword()
                            }
                        
                        // Validation indicator
                        Image(systemName: confirmPasswordValidationState.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor({
                                switch confirmPasswordValidationState {
                                case .none: return .clear
                                case .valid: return .green
                                case .invalid: return .red
                                }
                            }())
                            .font(.system(size: 16))
                            .opacity(confirmPassword.isEmpty ? 0 : 1)
                    }
                    
                    // Validation error message
                    if case .invalid(let message) = confirmPasswordValidationState {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
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
                }
            }
            .primaryAButtonStyle()
            .disabled(authService.isLoading || !isFormValid)
            
            Spacer()
            }
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Set initial focus to name field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .name
            }
        }
        .alert("Error", isPresented: .constant(authService.errorMessage != nil)) {
            Button("OK") {
                authService.errorMessage = nil
            }
        } message: {
            Text(authService.errorMessage ?? "")
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && 
        emailValidationState.isValid && 
        passwordValidationState.isValid && 
        confirmPasswordValidationState.isValid
    }
    
    private func validateEmail() {
        if email.isEmpty {
            emailValidationState = .none
        } else if isValidEmail(email) {
            emailValidationState = .valid
        } else {
            emailValidationState = .invalid("Please enter a valid email address")
        }
    }
    
    private func validatePassword() {
        if password.isEmpty {
            passwordValidationState = .none
            return
        }
        
        var errors: [String] = []
        
        if password.count < 8 {
            errors.append("At least 8 characters")
        }
        
        if !password.contains(where: { $0.isUppercase }) {
            errors.append("One uppercase letter")
        }
        
        if !password.contains(where: { $0.isLowercase }) {
            errors.append("One lowercase letter")
        }
        
        if !password.contains(where: { $0.isNumber }) {
            errors.append("One number")
        }
        
        if !password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) {
            errors.append("One special character")
        }
        
        if errors.isEmpty {
            passwordValidationState = .valid
        } else {
            passwordValidationState = .invalid(errors.joined(separator: ", "))
        }
    }
    
    private func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            confirmPasswordValidationState = .none
        } else if confirmPassword == password {
            confirmPasswordValidationState = .valid
        } else {
            confirmPasswordValidationState = .invalid("Passwords don't match")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
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
                
                VStack(spacing: 12) {
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("💡 Check your spam folder if you don't receive the email within a few minutes.")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
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
                    }
                }
                .primaryAButtonStyle()
                .disabled(authService.isLoading || email.isEmpty)
                
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

// MARK: - Main View
struct MainTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var geofenceStatusService = GeofenceStatusService()
    @State private var selectedTab: TabOption = .home
    
    enum TabOption: String, CaseIterable {
        case home = "home"
        case children = "children"
        case settings = "settings"
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .children: return "My Family"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .children: return "person.2"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main Content
                Group {
                    if authService.currentUser?.userType == .parent {
                        // Debug logging
                        
                        switch selectedTab {
                        case .home:
                            ParentHomeView()
                                .environmentObject(geofenceStatusService)
                        case .children:
                            ChildrenListView()
                        case .settings:
                            SettingsView()
                        }
                    } else {
                        // Debug logging
                        
                        switch selectedTab {
                        case .home:
                            ChildHomeView()
                        case .children:
                            EmptyView() // Children don't need this tab
                        case .settings:
                            SettingsView()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .accentColor(.white)
    }
}

// MARK: - Parent Home View
struct ParentHomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @EnvironmentObject var geofenceStatusService: GeofenceStatusService
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var geofenceService = GeofenceService()
    @StateObject private var mapViewModel = ParentMapViewModel()
    
    @State private var showingFamilySetup = false
    @State private var showingFamilyManagement = false
    @State private var showingInviteChild = false
    @State private var showingJoinFamily = false
    @State private var scrollOffset: CGFloat = 0
    @State private var panelHeight: CGFloat = 0.25
    @State private var isPanelExpanded: Bool = false
    @State private var buttonPosition: CGFloat = 0 // 0 = right side, 1 = left side
    @State private var isAnimating: Bool = false
    @State private var selectedChildForProfile: ChildDisplayItem?
    
    var body: some View {
        ZStack {
            // Map Section (Full Screen)
            ZStack {
                MapViewRepresentable(
                    childrenLocations: mapViewModel.childrenLocations,
                    region: $mapViewModel.region,
                    mapViewModel: mapViewModel,
                    familyService: familyService
                )
                .ignoresSafeArea()
                .padding(.bottom, 50)
                
                // White background to fill the gap
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(height: 50)
                        .ignoresSafeArea(.all, edges: .bottom)
                }
                
                // Map Controls Overlay
                VStack {
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
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            
            // Overlay Panel (Higher Z-Index with Drag)
            VStack {
                Spacer()
                
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        // Panel Header (tap area)
                        HStack {
                            Spacer()
                        }
                        .frame(height: 20)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Tap anywhere on header to expand (only when collapsed)
                            if !isPanelExpanded {
                                withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.36)) {
                                    isPanelExpanded = true
                                    panelHeight = 0.7
                                    buttonPosition = 1
                                }
                            }
                        }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 40) {
                            // Children List Section
                            VStack(spacing: 8) {
                                if let family = familyService.currentFamily {
                                    HStack {
                                        Text("My Family")
                                            .font(.radioCanadaBig(28, weight: .semibold))
                                        Spacer()
                                    }
                                }
                            
                            if let family = familyService.currentFamily {
                                let allChildren = familyService.getAllChildren()
                                if allChildren.isEmpty {
                                    // No children state
                                    VStack(spacing: 0) {
                                        // Background image section
                                        ZStack {
                                            // Background image (raised to show more of the nest)
                                            Image("Nest")
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .clipped()
                                                .offset(y: -20) // Raise the image to show more of the nest
                                            
                                            // Overlay content
                                            VStack(spacing: 0) {
                                                // Text at the top
                                                HStack {
                                                    Text("No children to\nlocate yet")
                                                        .font(.radioCanadaBig(28, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .multilineTextAlignment(.leading)
                                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 40)
                                                .padding(.top, UIScreen.main.bounds.height < 700 ? 80 : 100)
                                                
                                                Spacer()
                                                
                                                // Button at the bottom
                                                Button("Add a child") {
                                                    showingInviteChild = true
                                                }
                                                .primaryAButtonStyle()
                                                .padding(.horizontal, 15)
                                                .padding(.bottom, UIScreen.main.bounds.height < 700 ? 50 : 80)
                                            }
                                        }
                                    }
                                    .frame(height: UIScreen.main.bounds.height < 700 ? 200 : 220)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                                } else {
                                    // Children list (pending + accepted)
                                    VStack(spacing: 0) {
                                        ForEach(Array(allChildren.enumerated()), id: \.element.id) { index, child in
                                            let childLocation = mapViewModel.childrenLocations.first { $0.childId == child.id }
                                            let lastSeen = childLocation?.lastSeen
                                            let isLastChild = index == allChildren.count - 1
                                            
                                            ChildRowView(
                                                child: child,
                                                lastSeen: lastSeen,
                                                onTap: {
                                                    if !child.isPending {
                                                        // Collapse the panel
                                                        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.36)) {
                                                            isPanelExpanded = false
                                                            panelHeight = 0.25
                                                            buttonPosition = 0
                                                        }
                                                        
                                                        // Center on the child's location
                                                        mapViewModel.centerOnChild(childId: child.id)
                                                    }
                                                    // For pending children, we don't do anything on tap in the home view
                                                },
                                                onSettingsTap: {
                                                    selectedChildForProfile = child
                                                },
                                                showDivider: !isLastChild,
                                                geofenceStatus: geofenceStatusService.getStatusForChild(childId: child.id)
                                            )
                                        }
                                    }
                                }
                            } else {
                                // No family state
                                VStack(spacing: 0) {
                                    // Background image section
                                    ZStack {
                                        // Background image (original size)
                                        Image("Nest")
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .clipped()
                                        
                                        // Overlay content
                                        VStack(spacing: 0) {
                                            // Text at the top
                                            HStack {
                                                Text("Let's get\nstarted")
                                                    .font(.radioCanadaBig(28, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.leading)
                                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 40)
                                            .padding(.top, 60)
                                            
                                            Spacer()
                                            
                                            // Buttons at the bottom
                                            VStack(spacing: 12) {
                                                Button("Create a Family") {
                                                    showingFamilySetup = true
                                                }
                                                .primaryAButtonStyle()
                                                
                                                Button("Join Existing Family") {
                                                    showingJoinFamily = true
                                                }
                                                .font(.radioCanadaBig(16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 50)
                                                .background(Color.white.opacity(0.2))
                                                .cornerRadius(12)
                                            }
                                            .padding(.horizontal, 40)
                                            .padding(.bottom, 40)
                                        }
                                    }
                                }
                                .frame(height: 280)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Quick Actions Section
                        VStack(spacing: 16) {
                            // Removed "Quick Actions" title but kept spacing
                            VStack(spacing: 12) {
                                // Only show family-related buttons if a family exists
                                if familyService.currentFamily != nil {
                                    // Family Management Button
                                    NavigationLink(destination: ChildrenListView()) {
                                        HStack {
                                            Image(systemName: "person.2.fill")
                                                .font(.title2)
                                                .foregroundColor(.vibrantPurple)
                                            Text("Family Members")
                                                .font(.headline)
                                                .foregroundColor(.vibrantPurple)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.vibrantPurple)
                                        }
                                        .padding()
                                        .background(Color.familyMembersBg)
                                        .cornerRadius(12)
                                    }
                                    
                                    // Location Alerts Button
                                    NavigationLink(destination: GeofenceManagementView(familyId: familyService.currentFamily?.id ?? "")) {
                                        HStack {
                                            Image(systemName: "location.circle")
                                                .font(.title2)
                                                .foregroundColor(.vibrantBlue)
                                            Text("Location Alerts")
                                                .font(.headline)
                                                .foregroundColor(.vibrantBlue)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.vibrantBlue)
                                        }
                                        .padding()
                                        .background(Color.settingsBg)
                                        .cornerRadius(12)
                                    }
                                }
                                
                                // Settings Button
                                NavigationLink(destination: SettingsView()) {
                                    HStack {
                                        Image(systemName: "gear")
                                            .font(.title2)
                                            .foregroundColor(Color(white: 0.4))
                                        Text("Settings")
                                            .font(.headline)
                                            .foregroundColor(Color(white: 0.4))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Color(white: 0.4))
                                    }
                                    .padding()
                                    .background(Color(white: 0.92))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                                // Bottom padding for safe area
                                Color.clear.frame(height: 50)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                                }
                            )
                        }
                        .coordinateSpace(name: "scroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            // Throttle scroll offset updates to prevent performance issues
                            DispatchQueue.main.async {
                                scrollOffset = value
                            }
                        }
                    }
                    }
                    .background(
                        Color(UIColor.systemBackground)
                            .clipShape(RoundedCorner(radius: 20, corners: [.topLeft, .topRight]))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                    )
                    .frame(height: UIScreen.main.bounds.height * panelHeight)
                    
                    // Animated Hamburger Menu Button (overlaid on top)
                    Button(action: {
                        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.36)) {
                            isPanelExpanded.toggle()
                            panelHeight = isPanelExpanded ? 0.7 : 0.25
                            buttonPosition = isPanelExpanded ? 1 : 0
                        }
                        
                        // Transform to X after roll completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                // X transformation happens here
                            }
                        }
                    }) {
                        // Hamburger lines with rotation
                        ZStack {
                            if isPanelExpanded {
                                // X shape - two lines crossing
                                ZStack {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 2)
                                        .rotationEffect(.degrees(45))
                                    
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 2)
                                        .rotationEffect(.degrees(-45))
                                }
                            } else {
                                // Hamburger lines
                                VStack(spacing: 4) {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 2)
                                    
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 2)
                                    
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 2)
                                }
                            }
                        }
                        .rotationEffect(.degrees(-buttonPosition * 360)) // Rotate with the circle
                        .frame(width: 60, height: 60)
                        .background(Color.vibrantRed)
                        .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: buttonPosition == 0 ? UIScreen.main.bounds.width - 80 : 20)
                    .offset(y: -30)
                }
            }
        }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingFamilySetup) {
                FamilySetupView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingFamilyManagement) {
                FamilyManagementView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingInviteChild) {
                InviteChildView()
                    .environmentObject(familyService)
            }
            .sheet(isPresented: $showingJoinFamily) {
                JoinFamilyView()
                    .environmentObject(authService)
                    .environmentObject(familyService)
            }
            .sheet(item: $selectedChildForProfile) { child in
                ChildProfileView(childId: child.id, child: child, onChildRemoved: { _ in
                    // No removal animation needed from home view
                })
                    .environmentObject(familyService)
            }
            .onAppear {
                // Register for push notifications (geofence alerts)
                Task {
                    await notificationService.registerFCMToken()
                    print("📱 Parent registered for geofence notifications")
                }
                
                // Start listening for children locations when view appears
                if let parentId = authService.currentUser?.id, !parentId.isEmpty {
                    mapViewModel.startListeningForChildrenLocations(parentId: parentId, familyService: familyService)
                }
                
                // Center map on parent's location if no children are present
                if mapViewModel.childrenLocations.isEmpty, let parentLocation = locationService.currentLocation {
                    mapViewModel.centerOnLocation(parentLocation.coordinate)
                }
                
                // Start listening to geofence events for this family
                if let familyId = familyService.currentFamily?.id {
                    geofenceStatusService.listenToGeofenceEvents(familyId: familyId)
                } else {
                    print("❌ ParentHomeView - No family ID available for geofence status listening")
                }
                
                // Set panel to expanded state for new users (no family) or when no children
                if familyService.currentFamily == nil {
                    isPanelExpanded = true
                    panelHeight = 0.7
                    buttonPosition = 1 // Button should be on left when panel is expanded
                } else if let family = familyService.currentFamily, familyService.getAllChildren().isEmpty {
                    isPanelExpanded = true
                    panelHeight = 0.7
                    buttonPosition = 1 // Button should be on left when panel is expanded
                }
            }
            .onChange(of: familyService.currentFamily?.id) { familyId in
                // Start geofence status listening when family becomes available
                if let familyId = familyId {
                    geofenceStatusService.listenToGeofenceEvents(familyId: familyId)
                    // Keep panel expanded if no children, collapse if children exist
                    let allChildren = familyService.getAllChildren()
                    if allChildren.isEmpty {
                        isPanelExpanded = true
                        panelHeight = 0.7
                        buttonPosition = 1 // Button on left when expanded
                    } else {
                        isPanelExpanded = false
                        panelHeight = 0.25
                        buttonPosition = 0 // Button on right when collapsed
                    }
                } else {
                    geofenceStatusService.stopListening()
                    // Expand panel when family is removed (user becomes new again)
                    isPanelExpanded = true
                    panelHeight = 0.7
                    buttonPosition = 1 // Button on left when expanded
                }
            }
            .onChange(of: locationService.currentLocation) { newLocation in
                // Center map on parent's location when it updates and no children are present
                if mapViewModel.childrenLocations.isEmpty, let location = newLocation {
                    mapViewModel.centerOnLocation(location.coordinate)
                }
            }
            .onDisappear {
                // Stop listening to geofence events when view disappears
                geofenceStatusService.stopListening()
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
    @EnvironmentObject var familyService: FamilyService
    @StateObject private var geofenceService = GeofenceService()
    @State private var showingLocationPermissionAlert = false
    @State private var showingSettings = false
    
    private var permissionStatusText: String {
        locationService.getLocationPermissionStatusString()
    }
    
    private var needsAlwaysPermission: Bool {
        locationService.locationPermissionStatus != .authorizedAlways
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Permission Warning Banner
                if needsAlwaysPermission {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Background Tracking Limited")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        
                        Text("Current permission: \(permissionStatusText). For continuous tracking, enable 'Always Allow' in Settings.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }) {
                            HStack {
                                Text("Open Settings")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Debug Information Card
                VStack(spacing: 16) {
                    Text("Debug Information")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 12) {
                        // Child Name
                        HStack {
                            Text("Child Name:")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text(authService.currentUser?.name ?? "Not Available")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        // Family Name
                        HStack {
                            Text("Family Name:")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text(familyService.currentFamily?.name ?? "Not Available")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        // Family ID
                        HStack {
                            Text("Family ID:")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text(authService.currentUser?.familyId ?? "Not Available")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        // User ID
                        HStack {
                            Text("User ID:")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text(authService.currentUser?.id ?? "Not Available")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(authService)
            }
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
                if let currentUser = authService.currentUser, let familyId = currentUser.familyId {
                    Task {
                        await geofenceService.fetchGeofences(for: familyId)
                        geofenceService.startMonitoringGeofences(for: familyId)
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

// MARK: - Child Profile Data
class ChildProfileData: ObservableObject {
    @Published var childId: String = ""
    @Published var childName: String = ""
    @Published var isPresented: Bool = false
    
    func setChild(id: String, name: String) {
        childId = id
        childName = name
        isPresented = true
    }
    
    func dismiss() {
        isPresented = false
        // Don't clear the data immediately to avoid race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.childId = ""
            self.childName = ""
        }
    }
}

// MARK: - Children List View
struct ChildrenListView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @EnvironmentObject var invitationService: FamilyInvitationService
    @State private var showingInviteChild = false
    @State private var showingInviteParent = false
    @StateObject private var childProfileData = ChildProfileData()
    @State private var selectedPendingChild: ChildDisplayItem?
    @State private var removedChildId: String? = nil
    @State private var showingEditFamilyName = false
    @State private var editingFamilyName = ""
    @State private var isLoadingEditName = false
    
    var body: some View {
        CustomNavigationContainer(
            title: "",
            backgroundColor: .vibrantPurple
        ) {
            ScrollView {
                VStack(spacing: 20) {
                    if familyService.currentFamily != nil {
                        familyHeaderView
                        
                        Spacer()
                        
                        // Invite Buttons
                        VStack(spacing: 12) {
                            // Add Child Button
                            Button(action: {
                                showingInviteChild = true
                            }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Invite Child")
                                }
                            }
                            .primaryAButtonStyle()
                            
                            // Add Parent Button
                            Button(action: {
                                showingInviteParent = true
                            }) {
                                HStack {
                                    Image(systemName: "person.2.badge.plus")
                                    Text("Invite Parent")
                                }
                                .font(.radioCanadaBig(16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                        
                        familyMembersListView
                        
                        Spacer()
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
            }
        }
        .sheet(isPresented: $showingInviteChild) {
            InviteChildView()
                .environmentObject(familyService)
        }
        .sheet(isPresented: $showingInviteParent) {
            InviteParentView()
                .environmentObject(authService)
                .environmentObject(familyService)
        }
        .fullScreenCover(isPresented: $childProfileData.isPresented) {
            if !childProfileData.childId.isEmpty && !childProfileData.childName.isEmpty {
                // Create a simple child display item for the profile view
                let child = ChildDisplayItem(
                    from: FamilyMember(
                        role: .child,
                        name: childProfileData.childName,
                        joinedAt: Date()
                    ),
                    id: childProfileData.childId
                )
                ChildProfileView(childId: childProfileData.childId, child: child, onChildRemoved: { childId in
                    // Trigger the bubble pop animation
                    withAnimation(.easeInOut(duration: 0.8)) {
                        removedChildId = childId
                    }
                    // Clear the removed child after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        removedChildId = nil
                    }
                })
                    .environmentObject(familyService)
            }
        }
        .sheet(item: $selectedPendingChild) { pendingChild in
            // Use existing child management - show profile for pending children too
            ChildProfileView(childId: pendingChild.id, child: pendingChild, onChildRemoved: { childId in
                // Trigger the bubble pop animation
                withAnimation(.easeInOut(duration: 0.8)) {
                    removedChildId = childId
                }
                // Clear the removed child after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    removedChildId = nil
                }
            })
                .environmentObject(familyService)
                .onAppear {
                    print("🔍 ChildrenListView - Presenting child profile for pending child: \(pendingChild.name)")
                }
        }
        .sheet(isPresented: $showingEditFamilyName) {
            EditFamilyNameView(
                currentName: familyService.currentFamily?.name ?? "",
                isLoading: isLoadingEditName,
                onSave: { newName in
                    Task {
                        await updateFamilyName(newName)
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Views
    private var familyHeaderView: some View {
        Group {
            if let family = familyService.currentFamily {
                VStack(spacing: 16) {
                    Text(family.name)
                        .font(.radioCanadaBig(28, weight: .bold))
                        .foregroundColor(.white)
                        .onTapGesture {
                            editingFamilyName = family.name
                            showingEditFamilyName = true
                        }
                }
            }
        }
    }
    
    private var familyMembersListView: some View {
        let sortedMembers = getSortedFamilyMembers()
        let allChildren = familyService.getAllChildren()
        
        return VStack(alignment: .leading, spacing: 12) {
            if sortedMembers.count + allChildren.count <= 5 {
                // Show as VStack for small lists (no scroll needed)
                VStack(spacing: 8) {
                    // Show parents first
                    ForEach(sortedMembers, id: \.0) { userId, member in
                                    if member.role == .parent {
                                        HStack(spacing: 12) {
                                            // User icon
                                            Circle()
                                                .fill(Color.white.opacity(0.2))
                                                .frame(width: 55, height: 55)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.white)
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(member.name)
                                                    .font(.radioCanadaBig(24, weight: .regular))
                                                    .tracking(-1.2)
                                                    .foregroundColor(.white)
                                                
                                                Text("Parent")
                                                    .font(.radioCanadaBig(16, weight: .regular))
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                    }
                                }
                                
                                // Show all children (pending + accepted)
                                ForEach(Array(allChildren.enumerated()), id: \.element.id) { index, child in
                                    if removedChildId != child.id {
                                        VStack(spacing: 0) {
                                            HStack(spacing: 12) {
                                                // User icon with photo or initial
                                                Circle()
                                                    .fill(Color.white.opacity(0.2))
                                                    .frame(width: 55, height: 55)
                                                    .overlay(
                                                        Group {
                                                            if let imageBase64 = child.imageBase64, !imageBase64.isEmpty,
                                                               let imageData = Data(base64Encoded: imageBase64),
                                                               let uiImage = UIImage(data: imageData) {
                                                                Image(uiImage: uiImage)
                                                                    .resizable()
                                                                    .aspectRatio(contentMode: .fill)
                                                                    .frame(width: 50, height: 50)
                                                                    .clipShape(Circle())
                                                            } else {
                                                                Text(String(child.name.prefix(1)).uppercased())
                                                                    .font(.radioCanadaBig(24, weight: .bold))
                                                                    .foregroundColor(.white)
                                                            }
                                                        }
                                                    )
                                                
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(child.name)
                                                        .font(.radioCanadaBig(24, weight: .regular))
                                                        .tracking(-1.2)
                                                        .foregroundColor(.white)
                                                    
                                                    Text(child.isPending ? "Invite not accepted" : "Child")
                                                        .font(.radioCanadaBig(16, weight: .regular))
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                                
                                                Spacer()
                                                
                                                if !child.isPending {
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.5))
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if !child.isPending {
                                                    childProfileData.setChild(id: child.id, name: child.name)
                                                } else {
                                                    selectedPendingChild = child
                                                }
                                            }
                                            
                                            // Divider
                                            if index < allChildren.count - 1 {
                                                Divider()
                                                    .background(Color.white.opacity(0.2))
                                                    .padding(.horizontal, 15)
                                            }
                                        }
                                        .scaleEffect(removedChildId == child.id ? 0.1 : 1.0)
                                        .opacity(removedChildId == child.id ? 0.0 : 1.0)
                                        .animation(.easeInOut(duration: 0.8), value: removedChildId)
                                    }
                                }
                            }
                        } else {
                            // Show as ScrollView for larger lists
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    // Show parents first
                                    ForEach(sortedMembers, id: \.0) { userId, member in
                                        if member.role == .parent {
                                            HStack(spacing: 12) {
                                                // User icon
                                                Circle()
                                                    .fill(Color.white.opacity(0.2))
                                                    .frame(width: 55, height: 55)
                                                    .overlay(
                                                        Image(systemName: "person.fill")
                                                            .font(.system(size: 24))
                                                            .foregroundColor(.white)
                                                    )
                                                
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(member.name)
                                                        .font(.radioCanadaBig(24, weight: .regular))
                                                        .tracking(-1.2)
                                                        .foregroundColor(.white)
                                                    
                                                    Text("Parent")
                                                        .font(.radioCanadaBig(16, weight: .regular))
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 12)
                                        }
                                    }
                                    
                                    // Show all children (pending + accepted)
                                    ForEach(Array(allChildren.enumerated()), id: \.element.id) { index, child in
                                        if removedChildId != child.id {
                                            VStack(spacing: 0) {
                                                HStack(spacing: 12) {
                                                    // User icon with photo or initial
                                                    Circle()
                                                        .fill(Color.white.opacity(0.2))
                                                        .frame(width: 55, height: 55)
                                                        .overlay(
                                                            Group {
                                                                if let imageBase64 = child.imageBase64, !imageBase64.isEmpty,
                                                                   let imageData = Data(base64Encoded: imageBase64),
                                                                   let uiImage = UIImage(data: imageData) {
                                                                    Image(uiImage: uiImage)
                                                                        .resizable()
                                                                        .aspectRatio(contentMode: .fill)
                                                                        .frame(width: 50, height: 50)
                                                                        .clipShape(Circle())
                                                                } else {
                                                                    Text(String(child.name.prefix(1)).uppercased())
                                                                        .font(.radioCanadaBig(24, weight: .bold))
                                                                        .foregroundColor(.white)
                                                                }
                                                            }
                                                        )
                                                    
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(child.name)
                                                            .font(.radioCanadaBig(24, weight: .regular))
                                                            .tracking(-1.2)
                                                            .foregroundColor(.white)
                                                        
                                                        Text(child.isPending ? "Invite not accepted" : "Child")
                                                            .font(.radioCanadaBig(16, weight: .regular))
                                                            .foregroundColor(.white.opacity(0.7))
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    if !child.isPending {
                                                        Image(systemName: "chevron.right")
                                                            .font(.caption)
                                                            .foregroundColor(.white.opacity(0.5))
                                                    }
                                                }
                                                .padding(.vertical, 12)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    if !child.isPending {
                                                        childProfileData.setChild(id: child.id, name: child.name)
                                                    } else {
                                                        selectedPendingChild = child
                                                    }
                                                }
                                                
                                                // Divider
                                                if index < allChildren.count - 1 {
                                                    Divider()
                                                        .background(Color.white.opacity(0.2))
                                                        .padding(.horizontal, 15)
                                                }
                                            }
                                            .scaleEffect(removedChildId == child.id ? 0.1 : 1.0)
                                            .opacity(removedChildId == child.id ? 0.0 : 1.0)
                                            .animation(.easeInOut(duration: 0.8), value: removedChildId)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
        }
    }
    
    private func updateFamilyName(_ newName: String) async {
        guard let family = familyService.currentFamily else { return }
        
        await MainActor.run {
            isLoadingEditName = true
        }
        
        do {
            try await familyService.updateFamilyName(newName)
            await MainActor.run {
                showingEditFamilyName = false
                isLoadingEditName = false
            }
        } catch {
            print("❌ Error updating family name: \(error)")
            await MainActor.run {
                isLoadingEditName = false
            }
        }
    }
    
    private func getSortedFamilyMembers() -> [(String, FamilyMember)] {
        let members = familyService.getFamilyMembers()
        
        // Sort: parents first (alphabetically), then children (alphabetically)
        return members.sorted { first, second in
            let firstMember = first.1
            let secondMember = second.1
            
            // If one is parent and one is child, parent comes first
            if firstMember.role != secondMember.role {
                return firstMember.role == .parent
            }
            
            // If same role, sort alphabetically by name
            return firstMember.name.localizedCaseInsensitiveCompare(secondMember.name) == .orderedAscending
        }
    }
    
}

// MARK: - Child Profile View
struct ChildProfileView: View {
    let childId: String
    let child: ChildDisplayItem
    let onChildRemoved: ((String) -> Void)?
    @EnvironmentObject var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss
    
    @State private var childName: String
    @State private var showingEditName = false
    @State private var editingChildName = ""
    @State private var isLoadingEditName = false
    @State private var showingDeleteAlert = false
    @State private var newInviteCode: String?
    @State private var isGeneratingInvite = false
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isUploadingImage = false
    @State private var childImageURL: String?
    @State private var selectedPhotoItem: Any? // PhotosPickerItem for iOS 16+, nil for iOS 15
    
    init(childId: String, child: ChildDisplayItem, onChildRemoved: ((String) -> Void)? = nil) {
        self.childId = childId
        self.child = child
        self.onChildRemoved = onChildRemoved
        self._childName = State(initialValue: child.name)
    }
    
    var body: some View {
        ZStack {
            Color.vibrantPurple.ignoresSafeArea()
            
        VStack(spacing: 0) {
            // Custom Header with Back Button
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.radioCanadaBig(18, weight: .medium))
                        Text("Back")
                            .font(.radioCanadaBig(17, weight: .regular))
                    }
                    .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Child Profile")
                    .font(.radioCanadaBig(17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer to center the title
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.radioCanadaBig(18, weight: .medium))
                        .opacity(0)
                    Text("Back")
                        .font(.radioCanadaBig(17, weight: .regular))
                        .opacity(0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Main Content
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Image
                        ZStack {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else if let imageBase64 = child.imageBase64, !imageBase64.isEmpty,
                                      let imageData = Data(base64Encoded: imageBase64),
                                      let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else {
                                // Show initial
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Text(String(childName.prefix(1)).uppercased())
                                            .font(.radioCanadaBig(50, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            // Upload button overlay
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        print("🔍 Camera button pressed")
                                        showingImagePicker = true
                                    }) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Color.vibrantYellow)
                                            .clipShape(Circle())
                                    }
                                    .disabled(isUploadingImage)
                                }
                                .padding(8)
                            }
                            .frame(width: 120, height: 120)
                        }
                        
                        // Name Section
                        Text(childName)
                            .font(.radioCanadaBig(28, weight: .bold))
                            .foregroundColor(.white)
                            .onTapGesture {
                                editingChildName = childName
                                showingEditName = true
                            }
                        
                        // Status indicator for pending children
                        if child.isPending {
                            Text(child.status.displayName)
                                .font(.radioCanadaBig(14, weight: .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Reissue Invitation Button (for pending children)
                        if child.isPending {
                            Button(action: {
                                generateNewInviteCode()
                            }) {
                                if isGeneratingInvite {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Reissue Invitation")
                                    }
                                }
                            }
                            .primaryAButtonStyle()
                            .disabled(isGeneratingInvite)
                        } else {
                            // Generate New Invitation Button (for accepted children)
                            Button(action: {
                                generateNewInviteCode()
                            }) {
                                if isGeneratingInvite {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    HStack {
                                        Image(systemName: "envelope.badge")
                                        Text("Generate New Invitation Code")
                                    }
                                }
                            }
                            .primaryAButtonStyle()
                            .disabled(isGeneratingInvite)
                        }
                        
                        // New Invitation Code Display
                        if let inviteCode = newInviteCode {
                            VStack(spacing: 16) {
                                Text("Invitation Created!")
                                    .font(.radioCanadaBig(22, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Share this code with \(childName):")
                                    .font(.radioCanadaBig(16, weight: .regular))
                                    .foregroundColor(.white)
                                
                                Text(inviteCode)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.vibrantPurple)
                                    .padding()
                                    .background(Color.familyMembersBg)
                                    .cornerRadius(8)
                                
                                Text("This code expires in 24 hours")
                                    .font(.radioCanadaBig(12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                
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
                                        .font(.radioCanadaBig(12, weight: .regular))
                                        .foregroundColor(.vibrantPurple)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.familyMembersBg)
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
                                        .font(.radioCanadaBig(12, weight: .regular))
                                        .foregroundColor(.vibrantPurple)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.familyMembersBg)
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Delete Child Button
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text(child.isPending ? "Remove Pending Child" : "Remove from Family")
                            }
                        }
                        .primaryBButtonStyle()
                    }
                    
                    Spacer(minLength: 50) // Bottom padding
                }
                .padding()
            }
        }
        }
        .alert(child.isPending ? "Remove Pending Child" : "Remove Child", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeChild()
            }
        } message: {
            Text(child.isPending ? 
                 "Are you sure you want to remove \(childName) from your pending children? This will cancel their invitation." :
                 "Are you sure you want to remove \(childName) from your family? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditName) {
            EditChildNameView(
                currentName: childName,
                isLoading: isLoadingEditName,
                onSave: { newName in
                    Task {
                        await updateChildName(newName)
                    }
                }
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            if #available(iOS 16.0, *) {
                NavigationView {
                    VStack(spacing: 20) {
                        // Show selected image preview
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                                .padding()
                        }
                        
                        // PhotosPicker
                        PhotosPicker(selection: Binding<PhotosPickerItem?>(
                            get: { selectedPhotoItem as? PhotosPickerItem },
                            set: { selectedPhotoItem = $0 }
                        ), matching: .images, photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Select Photo")
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    .navigationTitle("Select Photo")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingImagePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingImagePicker = false
                            }
                            .disabled(selectedImage == nil)
                        }
                    }
                }
                .onChange(of: selectedPhotoItem as? PhotosPickerItem) { newValue in
                    print("🔍 PhotosPicker onChange triggered with item: \(newValue != nil ? "selected" : "nil")")
                    Task {
                        if let item = newValue {
                            await loadSelectedImage(from: item)
                        }
                    }
                }
            } else {
                // Fallback for iOS 15 - use UIImagePickerController
                ImagePickerView(selectedImage: $selectedImage)
            }
        }
        .onAppear {
            print("🔍 ChildProfileView onAppear called for child: \(childId)")
            loadExistingImage()
        }
    }
    
    private func updateChildName(_ newName: String) async {
        guard let familyId = familyService.currentFamily?.id else { return }
        
        isLoadingEditName = true
        
        do {
            try await familyService.updateFamilyMemberName(
                childId: childId,
                familyId: familyId,
                newName: newName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            childName = newName
            showingEditName = false
            isLoadingEditName = false
            print("✅ Successfully updated child name to: \(newName)")
        } catch {
            print("❌ Error updating child name: \(error)")
            isLoadingEditName = false
        }
    }
    
    @available(iOS 16.0, *)
    private func loadSelectedImage(from item: PhotosPickerItem) async {
        print("🔍 loadSelectedImage called with item: \(item)")
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("❌ Could not load image data")
                return
            }
            
            print("🔍 Successfully loaded image data: \(data.count) bytes")
            
            guard let image = UIImage(data: data) else {
                print("❌ Could not create UIImage from data")
                return
            }
            
            print("🔍 Successfully created UIImage")
            
            await MainActor.run {
                selectedImage = image
            }
            
            print("🔍 About to call storeImageAsBase64")
            // Store the image as base64 in Firestore
            await storeImageAsBase64(image: image)
            
        } catch {
            print("❌ Error loading selected image: \(error)")
        }
    }
    
    private func storeImageAsBase64(image: UIImage) async {
        print("🔍 Starting to store image as base64 for child: \(childId)")
        
        // Resize image to a smaller size first
        let resizedImage = resizeImage(image: image, targetSize: CGSize(width: 300, height: 300))
        
        // Compress image more aggressively to stay under Firestore limits
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.3) else {
            print("❌ Could not convert image to JPEG data")
            return
        }
        
        print("🔍 Image data size: \(imageData.count) bytes")
        
        // Check if still too large
        if imageData.count > 1000000 { // 1MB limit
            print("❌ Image still too large after compression: \(imageData.count) bytes")
            return
        }
        
        await MainActor.run {
            isUploadingImage = true
        }
        
        do {
            // Convert image to base64 string
            let base64String = imageData.base64EncodedString()
            print("🔍 Base64 string length: \(base64String.count)")
            
            // Save the base64 image data to the family document
            if let familyId = familyService.currentFamily?.id {
                print("🔍 Saving to family: \(familyId)")
                try await familyService.updateChildImageBase64(
                    childId: childId,
                    familyId: familyId,
                    imageBase64: base64String
                )
                
                await MainActor.run {
                    childImageURL = base64String // Store base64 as "URL" for consistency
                    isUploadingImage = false
                }
                
                print("✅ Successfully stored child image as base64")
            } else {
                print("❌ No family ID found")
                await MainActor.run {
                    isUploadingImage = false
                }
            }
            
        } catch {
            print("❌ Error storing image: \(error)")
            await MainActor.run {
                isUploadingImage = false
            }
        }
    }
    
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func saveImageURLToFamily(imageURL: String) async {
        do {
            if let familyId = familyService.currentFamily?.id {
                try await familyService.updateChildImageURL(
                    childId: childId,
                    familyId: familyId,
                    imageURL: imageURL
                )
                print("✅ Successfully saved image URL to family document")
            }
        } catch {
            print("❌ Error saving image URL: \(error)")
        }
    }
    
    private func loadExistingImage() {
        print("🔍 Loading existing image for child: \(childId)")
        
        // Get the child's image from the family data
        let familyMembers = familyService.getFamilyMembers()
        print("🔍 Found \(familyMembers.count) family members")
        
        if let member = familyMembers.first(where: { $0.0 == childId }) {
            print("🔍 Found child member: \(member.1.name)")
            print("🔍 Child has imageBase64: \(member.1.imageBase64 != nil)")
            print("🔍 Child has imageURL: \(member.1.imageURL != nil)")
            
            // Try base64 first, then fallback to URL
            if let imageBase64 = member.1.imageBase64 {
                print("🔍 Loading image from base64 (length: \(imageBase64.count))")
                loadImageFromBase64(imageBase64)
            } else if let imageURL = member.1.imageURL {
                print("🔍 Loading image from URL: \(imageURL)")
                childImageURL = imageURL
                loadImageFromURL(imageURL)
            } else {
                print("🔍 No image data found for child")
            }
        } else {
            print("🔍 Child not found in family members")
        }
    }
    
    private func loadImageFromBase64(_ base64String: String) {
        print("🔍 Attempting to load image from base64 string")
        guard let data = Data(base64Encoded: base64String),
              let image = UIImage(data: data) else {
            print("❌ Could not decode base64 image")
            return
        }
        
        print("✅ Successfully loaded image from base64")
        selectedImage = image
        childImageURL = base64String // Store for consistency
    }
    
    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid image URL: \(urlString)")
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                    }
                }
            } catch {
                print("❌ Error loading image from URL: \(error)")
            }
        }
    }
    
    private func generateNewInviteCode() {
        Task {
            await MainActor.run {
                isGeneratingInvite = true
                newInviteCode = nil // Clear any existing code
            }
            
            do {
                if let familyId = familyService.currentFamily?.id {
                    let invitationService = FamilyInvitationService()
                    let newCode = try await invitationService.createInvitation(familyId: familyId, childName: childName)
                    
                    await MainActor.run {
                        newInviteCode = newCode
                        isGeneratingInvite = false
                    }
                }
            } catch {
                print("❌ Error creating new invitation: \(error)")
                await MainActor.run {
                    isGeneratingInvite = false
                }
            }
        }
    }
    
    private func removeChild() {
        // Navigate back immediately
        dismiss()
        
        Task {
            // Wait a bit for navigation to complete
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            do {
                if let familyId = familyService.currentFamily?.id {
                    if child.isPending {
                        // For pending children, just remove them from the family members
                        try await familyService.removeChildFromFamily(childId: childId, familyId: familyId)
                    } else {
                        // For accepted children, use the existing logic
                        try await familyService.removeChildFromFamily(childId: childId, familyId: familyId)
                    }
                    
                    await MainActor.run {
                        // Trigger the bubble pop animation
                        onChildRemoved?(childId)
                    }
                }
            } catch {
                print("❌ Error removing child: \(error)")
                // Even if removal fails, still trigger animation
                await MainActor.run {
                    // Trigger the bubble pop animation
                    onChildRemoved?(childId)
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("User: \(authService.currentUser?.name ?? "Unknown")")
                    Text("Email: \(authService.currentUser?.email ?? "Unknown")")
                    Text("Type: \(authService.currentUser?.userType.rawValue.capitalized ?? "Unknown")")
                }
                .font(.body)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Test notification button (child only)
                if authService.currentUser?.userType == .child {
                    Button(action: {
                        Task {
                            await notificationService.sendTestGeofenceNotification()
                        }
                    }) {
                        HStack {
                            if notificationService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Sending...")
                            } else {
                                Image(systemName: "bell.badge")
                                Text("Test Parent Notification")
                            }
                        }
                    }
                    .primaryBButtonStyle()
                    .disabled(notificationService.isLoading)
                    .padding(.horizontal)
                }
                
                // Test self-notification button (parent only)
                if authService.currentUser?.userType == .parent {
                    Button(action: {
                        Task {
                            await notificationService.sendTestSelfNotification()
                        }
                    }) {
                        HStack {
                            if notificationService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Sending...")
                            } else {
                                Image(systemName: "bell.badge.fill")
                                Text("Test Self Notification")
                            }
                        }
                    }
                    .primaryBButtonStyle()
                    .disabled(notificationService.isLoading)
                    .padding(.horizontal)
                }
                
                Button("Sign Out") {
                    Task {
                        print("🔐 Sign out button tapped")
                        await authService.signOut()
                        print("🔐 Sign out process completed")
                        // Dismiss the settings sheet after sign out
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
                .primaryBButtonStyle()
                
                Spacer()
            }
            .background(Color.vibrantRed)
            .alert(
                notificationService.errorMessage != nil ? "Error" : "Success",
                isPresented: $notificationService.showTestAlert
            ) {
                Button("OK") {
                    notificationService.showTestAlert = false
                    notificationService.errorMessage = nil
                    notificationService.successMessage = nil
                }
            } message: {
                if let errorMessage = notificationService.errorMessage {
                    Text(errorMessage)
                } else if let successMessage = notificationService.successMessage {
                    Text(successMessage)
                }
            }
        }
    }
}


// MARK: - Parent Map View
struct ParentMapView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @StateObject private var mapViewModel = ParentMapViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                MapViewRepresentable(
                    childrenLocations: mapViewModel.childrenLocations,
                    region: $mapViewModel.region,
                    mapViewModel: mapViewModel,
                    familyService: familyService
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
                    mapViewModel.startListeningForChildrenLocations(parentId: parentId, familyService: familyService)
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
        center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), // Will be updated when children are found
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    // Color palette for different children pins
    private let childColors: [UIColor] = [
        .systemBlue, .systemGreen, .systemOrange, .systemPurple, 
        .systemRed, .systemYellow, .systemTeal, .systemPink
    ]
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private weak var familyService: FamilyService?
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        listeners.forEach { $0.remove() }
        cancellables.removeAll()
        print("🛑 ParentMapViewModel deallocated")
    }
    
    // Get a consistent color for a child based on their ID
    func getColorForChild(childId: String) -> UIColor {
        let hash = childId.hashValue
        let index = abs(hash) % childColors.count
        let color = childColors[index]
        return color
    }
    
    func startListeningForChildrenLocations(parentId: String, familyService: FamilyService) {
        // Validate parentId before making Firestore calls
        guard !parentId.isEmpty else {
            print("❌ Cannot start listening: parentId is empty")
            return
        }
        
        
        // Store reference to family service
        self.familyService = familyService
        
        // Listen to family service changes to automatically refresh when children are added/removed
        Task { @MainActor in
            familyService.$familyMembers
                .sink { [weak self] _ in
                    self?.refreshChildrenLocations()
                }
                .store(in: &cancellables)
        }
        
        // Stop existing listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        childrenLocations.removeAll()
        
        // Get all children (pending + accepted) from family service and start listening to their locations
        Task { @MainActor in
            // Wait for family data to be loaded
            var attempts = 0
            while attempts < 10 { // Try for up to 5 seconds
                let childIds = familyService.getAllChildrenIds()
                if !childIds.isEmpty {
                    
                    // Start listening to each child's location
                    for childId in childIds {
                        listenForChildLocation(childId: childId)
                    }
                    return
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
                attempts += 1
            }
        }
    }
    
    
    private func listenForChildLocation(childId: String) {
        // Validate childId before making Firestore calls
        guard !childId.isEmpty else {
            print("❌ Cannot listen for child location: childId is empty")
            return
        }
        
        
        let listener = db.collection("locations").document(childId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ MapViewModel - Error listening for child location \(childId): \(error)")
                    return
                }
                
                guard let document = documentSnapshot else {
                    return
                }
                
                if !document.exists {
                    return
                }
                
                guard let data = document.data() else {
                    return
                }
                
                
                guard let locationData = try? Firestore.Decoder().decode(LocationData.self, from: data) else {
                    print("❌ MapViewModel - Failed to decode location data for child \(childId)")
                    return
                }
                
                // Get child name
                self.fetchChildName(childId: childId, familyService: self.familyService) { childName in
                    let childLocation = ChildLocationData(
                        childId: childId,
                        location: locationData,
                        lastSeen: locationData.lastUpdated,
                        childName: childName
                    )
                    
                    // Update or add child location
                    DispatchQueue.main.async {
                        let wasEmpty = self.childrenLocations.isEmpty
                        
                        
                        if let index = self.childrenLocations.firstIndex(where: { $0.childId == childId }) {
                            self.childrenLocations[index] = childLocation
                        } else {
                            self.childrenLocations.append(childLocation)
                        }
                        
                        // Check if we should center the map now
                        self.checkAndCenterMapIfNeeded()
                    }
                }
            }
        
        listeners.append(listener)
    }
    
    private func fetchChildName(childId: String, familyService: FamilyService?, completion: @escaping (String) -> Void) {
        // Validate childId before making Firestore calls
        guard !childId.isEmpty else {
            print("❌ Cannot fetch child name: childId is empty")
            completion("Unknown Child")
            return
        }
        
        // Try to get the name from FamilyService first
        if let familyService = familyService {
            Task { @MainActor in
                let familyMembers = familyService.getFamilyMembers()
                if let member = familyMembers.first(where: { $0.0 == childId }) {
                    completion(member.1.name)
                    return
                }
                
                // Fallback to Firestore if not found in family
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
            return
        }
    }
    
    private func checkAndCenterMapIfNeeded() {
        // Only center if we have children and haven't centered yet, or if we have more children than expected
        guard !childrenLocations.isEmpty else { return }
        
        // Get expected number of children from family service
        Task { @MainActor in
            let expectedChildrenCount = familyService?.getAllChildrenIds().count ?? 0
            
            
            // Center if we have all expected children, or if we have at least one child
            if childrenLocations.count >= expectedChildrenCount || childrenLocations.count >= 1 {
                centerOnChildren()
            }
        }
    }
    
    func centerOnChildren() {
        guard !childrenLocations.isEmpty else { 
            return 
        }
        
        
        let coordinates = childrenLocations.map { CLLocationCoordinate2D(
            latitude: $0.location.lat,
            longitude: $0.location.lng
        )}
        
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLng = coordinates.map { $0.longitude }.min() ?? 0
        let maxLng = coordinates.map { $0.longitude }.max() ?? 0
        
        // Ensure minimum span to show both children clearly
        let minSpan = 0.05 // Increased minimum span for better visibility
        let actualLatSpan = max(maxLat - minLat, minSpan)
        let actualLngSpan = max(maxLng - minLng, minSpan)
        
        // Calculate span based on actual distance between children with padding
        let latDistance = maxLat - minLat
        let lngDistance = maxLng - minLng
        
        // Add much more padding around the children's area to ensure they're above white panel
        let paddedLatSpan = max(latDistance * 3.0, 0.05) // Increased to 3x with minimum 0.05 degrees
        let paddedLngSpan = max(lngDistance * 3.0, 0.05) // Increased to 3x with minimum 0.05 degrees
        
        let span = MKCoordinateSpan(
            latitudeDelta: paddedLatSpan,
            longitudeDelta: paddedLngSpan
        )
        
        // Adjust southward shift based on actual distance between children
        // Minimal shift to account for larger 60px pins
        let childrenDistance = maxLat - minLat
        let southwardShift = max(childrenDistance * 1.0, 0.02) // Reduced to 1.0x with minimum 0.02 degrees for larger pins
        let centerLat = (minLat + maxLat) / 2 - southwardShift
        let center = CLLocationCoordinate2D(
            latitude: centerLat,
            longitude: (minLng + maxLng) / 2
        )
        
        region = MKCoordinateRegion(center: center, span: span)
        
        
        // Force a small delay to ensure map renders properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Trigger a small region change to force map rendering
            var adjustedRegion = self.region
            adjustedRegion.span.latitudeDelta *= 1.001
            adjustedRegion.span.longitudeDelta *= 1.001
            self.region = adjustedRegion
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.region = self.region
            }
        }
    }
    
    func centerOnChild(childId: String) {
        guard let childLocation = childrenLocations.first(where: { $0.childId == childId }) else {
            return
        }
        
        
        let coordinate = CLLocationCoordinate2D(
            latitude: childLocation.location.lat,
            longitude: childLocation.location.lng
        )
        
        // Set a reasonable span for viewing a single child with larger pins
        let span = MKCoordinateSpan(
            latitudeDelta: 0.015, // Increased span for larger pins
            longitudeDelta: 0.015
        )
        
        // Center the map on the child with minimal southward shift to account for larger 60px pins
        let centerLat = coordinate.latitude - 0.004 // Minimal southward shift for larger pins
        let center = CLLocationCoordinate2D(
            latitude: centerLat,
            longitude: coordinate.longitude
        )
        
        region = MKCoordinateRegion(center: center, span: span)
        
        // Force a small delay to ensure map renders properly even when re-centering on same child
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Trigger a small region change to force map rendering
            var adjustedRegion = self.region
            adjustedRegion.span.latitudeDelta *= 1.001
            adjustedRegion.span.longitudeDelta *= 1.001
            self.region = adjustedRegion
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.region = self.region
            }
        }
    }
    
    func centerOnLocation(_ coordinate: CLLocationCoordinate2D) {
        // Set a reasonable span for viewing the parent's location
        let span = MKCoordinateSpan(
            latitudeDelta: 0.01, // Smaller span for parent's location
            longitudeDelta: 0.01
        )
        
        region = MKCoordinateRegion(center: coordinate, span: span)
        print("📍 Map centered on parent location: \(coordinate.latitude), \(coordinate.longitude)")
    }
    
    func refreshChildrenLocations() {
        
        // Force refresh by restarting listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        childrenLocations.removeAll()
        
        // Restart listening if we have a family service
        if let familyService = familyService {
            // Get all children (pending + accepted) from family service and start listening to their locations
            Task { @MainActor in
                let childIds = familyService.getAllChildrenIds()
                
                
                // Start listening to each child's location
                for childId in childIds {
                    listenForChildLocation(childId: childId)
                }
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
        
    }
    
    private func isListeningToChild(childId: String) -> Bool {
        return childrenLocations.contains { $0.childId == childId }
    }
}

// MARK: - Map View Representable
struct MapViewRepresentable: UIViewRepresentable {
    let childrenLocations: [ChildLocationData]
    @Binding var region: MKCoordinateRegion
    let mapViewModel: ParentMapViewModel
    let familyService: FamilyService
    
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
            // Get the child's image data from family service
            let familyMembers = familyService.getFamilyMembers()
            let childImageBase64 = familyMembers.first { $0.0 == childLocation.childId }?.1.imageBase64
            
            let annotation = ChildLocationAnnotation(
                coordinate: CLLocationCoordinate2D(
                    latitude: childLocation.location.lat,
                    longitude: childLocation.location.lng
                ),
                childId: childLocation.childId,
                childName: childLocation.childName,
                lastSeen: childLocation.lastSeen,
                pinColor: mapViewModel.getColorForChild(childId: childLocation.childId),
                imageBase64: childImageBase64
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
                // Create a custom annotation view for larger pins
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Customize the annotation with a larger custom view
            if let customView = annotationView {
                // Create a larger custom pin (60x60 instead of default smaller size)
                let pinSize: CGFloat = 60
                customView.frame = CGRect(x: 0, y: 0, width: pinSize, height: pinSize)
                
                // Clear any existing subviews to prevent overlapping
                customView.subviews.forEach { $0.removeFromSuperview() }
                
                // Determine location age
                let locationAge = getLocationAge(childAnnotation.lastSeen)
                
                // Create the custom pin view (no per-child colors, just status-based pin images)
                let pinView = createCustomPinView(
                    size: pinSize,
                    childName: childAnnotation.childName,
                    imageBase64: childAnnotation.imageBase64,
                    locationAge: locationAge
                )
                
                customView.addSubview(pinView)
                pinView.center = CGPoint(x: pinSize/2, y: pinSize/2)
                
                // Add a subtle shadow to make the pin stand out
                customView.layer.shadowColor = UIColor.black.cgColor
                customView.layer.shadowOffset = CGSize(width: 0, height: 3)
                customView.layer.shadowRadius = 6
                customView.layer.shadowOpacity = 0.4
            }
            
            return annotationView
        }
        
        private func isLocationRecent(_ date: Date) -> Bool {
            date.timeIntervalSinceNow > -1800 // 30 minutes
        }
        
        private func getLocationAge(_ date: Date) -> LocationAge {
            let timeInterval = date.timeIntervalSinceNow
            
            if timeInterval > -300 { // Within 5 minutes
                return .veryRecent
            } else if timeInterval > -1800 { // Within 30 minutes
                return .recent
            } else {
                return .old
            }
        }
        
        private enum LocationAge {
            case veryRecent // Within 5 minutes
            case recent     // 5-30 minutes
            case old        // Older than 30 minutes
        }
        
        /// Determines the pin image name based on location status
        private func getPinImageName(for locationAge: LocationAge) -> String {
            switch locationAge {
            case .veryRecent, .recent:
                return "GreenPin" // Successfully tracked
            case .old:
                return "OrangePin" // Old location
            }
        }
        
        private func createCustomPinView(size: CGFloat, childName: String, imageBase64: String?, locationAge: LocationAge) -> UIView {
            let containerView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            containerView.backgroundColor = .clear
            
            // Get the appropriate pin image based on location status
            let pinImageName = getPinImageName(for: locationAge)
            
            // Create pin background using the pin image
            let pinImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            pinImageView.image = UIImage(named: pinImageName)
            pinImageView.contentMode = .scaleAspectFit
            containerView.addSubview(pinImageView)
            
            // Check if child has a photo
            let hasPhoto = imageBase64 != nil && Data(base64Encoded: imageBase64!) != nil
            
            // Calculate overlay size and position (centered on the wider part of the pin)
            let overlaySize: CGFloat = size * 0.58 // Slightly smaller than the circle was
            let overlayYOffset: CGFloat = -size * 0.1 // Raise it to center on the widest part of pin
            
            if hasPhoto {
                // Add photo in the center
                let photoImageView = UIImageView(frame: CGRect(
                    x: (size - overlaySize) / 2,
                    y: (size - overlaySize) / 2 + overlayYOffset,
                    width: overlaySize,
                    height: overlaySize
                ))
                photoImageView.layer.cornerRadius = overlaySize / 2
                photoImageView.clipsToBounds = true
                photoImageView.contentMode = .scaleAspectFill
                photoImageView.layer.borderWidth = 2
                photoImageView.layer.borderColor = UIColor.white.cgColor
                
                if let imageData = Data(base64Encoded: imageBase64!), let childImage = UIImage(data: imageData) {
                    photoImageView.image = childImage
                }
                
                containerView.addSubview(photoImageView)
            } else {
                // Add initial letter in a circle
                let initialView = UIView(frame: CGRect(
                    x: (size - overlaySize) / 2,
                    y: (size - overlaySize) / 2 + overlayYOffset,
                    width: overlaySize,
                    height: overlaySize
                ))
                initialView.layer.cornerRadius = overlaySize / 2
                initialView.backgroundColor = .white
                initialView.layer.borderWidth = 2
                initialView.layer.borderColor = UIColor.lightGray.cgColor
                
                let initialLabel = UILabel(frame: CGRect(x: 0, y: 0, width: overlaySize, height: overlaySize))
                initialLabel.text = String(childName.prefix(1)).uppercased()
                initialLabel.textAlignment = .center
                initialLabel.font = UIFont.systemFont(ofSize: overlaySize * 0.5, weight: .bold)
                initialLabel.textColor = .darkGray
                
                initialView.addSubview(initialLabel)
                containerView.addSubview(initialView)
            }
            
            return containerView
        }
        
        private func addStatusIndicator(to containerView: UIView, size: CGFloat, locationAge: LocationAge) {
            let indicatorSize: CGFloat = size * 0.3
            let indicatorView = UIView(frame: CGRect(
                x: size - indicatorSize - 2,
                y: 2,
                width: indicatorSize,
                height: indicatorSize
            ))
            indicatorView.layer.cornerRadius = indicatorSize / 2
            indicatorView.layer.borderWidth = 2
            indicatorView.layer.borderColor = UIColor.white.cgColor
            
            // Add icon based on location age
            let iconSize: CGFloat = indicatorSize * 0.6
            let iconImageView = UIImageView(frame: CGRect(
                x: (indicatorSize - iconSize) / 2,
                y: (indicatorSize - iconSize) / 2,
                width: iconSize,
                height: iconSize
            ))
            iconImageView.tintColor = .white
            iconImageView.contentMode = .scaleAspectFit
            
            switch locationAge {
            case .veryRecent:
                // Green checkmark for locations within 5 minutes
                indicatorView.backgroundColor = UIColor.systemGreen
                iconImageView.image = UIImage(systemName: "checkmark")
                
            case .recent:
                // Yellow clock for locations 5-30 minutes old
                indicatorView.backgroundColor = UIColor.systemYellow
                iconImageView.image = UIImage(systemName: "clock")
                
            case .old:
                // Red error for locations older than 30 minutes
                indicatorView.backgroundColor = UIColor.systemRed
                iconImageView.image = UIImage(systemName: "exclamationmark")
            }
            
            indicatorView.addSubview(iconImageView)
            containerView.addSubview(indicatorView)
        }
    }
}

// MARK: - Child Location Annotation
class ChildLocationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let childId: String
    let childName: String
    let lastSeen: Date
    let pinColor: UIColor
    let imageBase64: String?
    
    init(coordinate: CLLocationCoordinate2D, childId: String, childName: String, lastSeen: Date, pinColor: UIColor = .systemBlue, imageBase64: String? = nil) {
        self.coordinate = coordinate
        self.childId = childId
        self.childName = childName
        self.lastSeen = lastSeen
        self.pinColor = pinColor
        self.imageBase64 = imageBase64
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
                    }
                }
                .primaryAButtonStyle()
                .disabled(isLoading || childName.isEmpty)
                
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

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Rounded Corner Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Edit Family Name View
struct EditFamilyNameView: View {
    let currentName: String
    let isLoading: Bool
    let onSave: (String) async -> Void
    
    @State private var familyName: String
    @Environment(\.dismiss) private var dismiss
    
    init(currentName: String, isLoading: Bool, onSave: @escaping (String) async -> Void) {
        self.currentName = currentName
        self.isLoading = isLoading
        self.onSave = onSave
        self._familyName = State(initialValue: currentName)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter family name", text: $familyName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
            }
            .navigationTitle("Edit Family Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            await onSave(familyName)
                        }
                    }
                    .disabled(familyName.isEmpty || familyName == currentName || isLoading)
                }
            }
        }
    }
}

// MARK: - Edit Child Name View
struct EditChildNameView: View {
    let currentName: String
    let isLoading: Bool
    let onSave: (String) async -> Void
    
    @State private var childName: String
    @Environment(\.dismiss) private var dismiss
    
    init(currentName: String, isLoading: Bool, onSave: @escaping (String) async -> Void) {
        self.currentName = currentName
        self.isLoading = isLoading
        self.onSave = onSave
        self._childName = State(initialValue: currentName)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Child's Name")
                            .font(.radioCanadaBig(13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter child's name", text: $childName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
            }
            .navigationTitle("Edit Child's Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            await onSave(childName)
                        }
                    }
                    .disabled(childName.isEmpty || childName == currentName || isLoading)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - ImagePickerView for iOS 15 compatibility
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Child Pin View
struct ChildPinView: View {
    let child: ChildDisplayItem
    let lastSeen: Date?
    
    var body: some View {
        ZStack {
            // Pin background image
            Image(pinImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 55, height: 55)
            
            // Child photo or initial overlay
            if let imageBase64 = child.imageBase64, !imageBase64.isEmpty {
                // Load and display child photo from base64
                if let imageData = Data(base64Encoded: imageBase64),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                        .offset(y: -6) // Raise to center on widest part of pin
                } else {
                    // Fallback to initial if base64 decode fails
                    Text(String(child.name.prefix(1)).uppercased())
                        .font(.radioCanadaBig(20, weight: .bold))
                        .foregroundColor(.primary)
                        .offset(y: -6) // Raise to center on widest part of pin
                }
            } else {
                // First initial
                Text(String(child.name.prefix(1)).uppercased())
                    .font(.radioCanadaBig(20, weight: .bold))
                    .foregroundColor(.primary)
                    .offset(y: -6) // Raise to center on widest part of pin
            }
        }
    }
    
    private var pinImageName: String {
        if child.isPending {
            return "OrangePin" // Pending invitation
        }
        
        guard let lastSeen = lastSeen else {
            return "RedPin" // No location data = offline
        }
        
        // Use existing isLocationRecent logic
        if isLocationRecent(lastSeen) {
            return "GreenPin" // Successfully tracked
        } else {
            return "OrangePin" // Old location
        }
    }
    
    private func isLocationRecent(_ date: Date) -> Bool {
        date.timeIntervalSinceNow > -300 // 5 minutes
    }
}

// MARK: - Child Row View
struct ChildRowView: View {
    let child: ChildDisplayItem
    let lastSeen: Date?
    let onTap: () -> Void
    let onSettingsTap: (() -> Void)?
    let showDivider: Bool
    let geofenceStatus: GeofenceStatus? // New parameter
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Child pin
                ChildPinView(child: child, lastSeen: lastSeen)
                
                // Child info
                VStack(alignment: .leading, spacing: 1) {
                    Text(child.name)
                        .font(.radioCanadaBig(24, weight: .regular))
                        .tracking(-1.2) // 5% reduced letter spacing (32 * 0.05 = 1.6)
                        .foregroundColor(.primary)
                    
                    Text(statusText)
                        .font(.radioCanadaBig(16, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Settings button
                if let onSettingsTap = onSettingsTap {
                    Button(action: onSettingsTap) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            // Divider
            if showDivider {
                Divider()
                    .padding(.horizontal, 15) // 15pt from each side
            }
        }
    }
    
    private var statusText: String {
        if child.isPending {
            return "Invite not accepted"
        }
        
        // Check if child is in a geofence (only show if last event was "enter")
        if let status = geofenceStatus, status.lastEvent == .enter {
            // Child is currently inside a geofence
            if let lastSeen = lastSeen {
                return "In \"\(status.geofenceName)\" • \(formatTime(lastSeen))"
            } else {
                return "In \"\(status.geofenceName)\""
            }
        }
        
        guard let lastSeen = lastSeen else {
            return "Offline"
        }
        
        if isLocationRecent(lastSeen) {
            return "Located \(formatTime(lastSeen))"
        } else {
            return "Last seen \(formatTime(lastSeen))"
        }
    }
    
    private func isLocationRecent(_ date: Date) -> Bool {
        date.timeIntervalSinceNow > -300 // 5 minutes
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
