import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Accept Family Invitation View
struct AcceptFamilyInvitationView: View {
    @StateObject private var invitationService = FamilyInvitationService()
    @EnvironmentObject var familyService: FamilyService
    @EnvironmentObject var locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingWelcome = false
    
    var body: some View {
        Group {
            if showingWelcome {
                ChildWelcomeView {
                    // Refresh family listener and force location update before dismissing
                    Task {
                        await familyService.forceRefreshFamilyListener()
                        // Force location update so parent map shows child immediately
                        locationService.forceLocationUpdate()
                        dismiss()
                    }
                }
            } else {
                NavigationView {
                    ScrollView {
                        VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("Join Your Family")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Enter the invitation code your parent shared with you to join your family on Located.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Invitation Code Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invitation Code")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("e.g., ABC123", text: $inviteCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                        }
                        .padding(.horizontal)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        // Accept Invitation Button
                        Button(action: acceptInvitation) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark")
                                }
                                Text(isLoading ? "Joining Family..." : "Join Family")
                            }
                        }
                        .primaryAButtonStyle()
                        .disabled(inviteCode.isEmpty || isLoading)
                        
                        // Skip Button
                        Button("Skip for now") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                        }
                        .padding()
                    }
                    .navigationTitle("Join Family")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Skip") {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func acceptInvitation() {
        guard !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter an invitation code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await invitationService.acceptInvitation(
                    inviteCode: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                )
                
                await MainActor.run {
                    self.isLoading = false
                    self.showingWelcome = true
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

// MARK: - Child Welcome View
struct ChildWelcomeView: View {
    let onNext: () -> Void
    @State private var isSettingUp = true
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo - matching parent loading screen
            VStack(spacing: 24) {
                Circle()
                    .fill(Color.vibrantYellow)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image("AppSplash")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    )
                
                // Welcome Text
                VStack(spacing: 16) {
                    if isSettingUp {
                        Text("Setting up your account...")
                            .font(.radioCanadaBig(32, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text("Please wait while we prepare everything for you")
                            .font(.radioCanadaBig(18, weight: .regular))
                            .foregroundColor(.black.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Loading indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(1.2)
                            .padding(.top, 20)
                    } else {
                        Text("Welcome to Located!")
                            .font(.radioCanadaBig(32, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text("You're all set to start sharing your location with your family")
                            .font(.radioCanadaBig(18, weight: .regular))
                            .foregroundColor(.black.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            }
            
            Spacer()
            
            // Next Button (only show when not setting up)
            if !isSettingUp {
                Button(action: onNext) {
                    HStack(spacing: 12) {
                        Text("Next")
                            .font(.radioCanadaBig(18, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .primaryAButtonStyle()
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // After a short delay, transition from "Setting up" to "Welcome"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isSettingUp = false
                }
            }
        }
        .background(Color.vibrantYellow)
        .ignoresSafeArea()
    }
}

// MARK: - Child Welcome Back View
struct ChildWelcomeBackView: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo - matching parent loading screen
            VStack(spacing: 24) {
                Circle()
                    .fill(Color.vibrantYellow)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image("AppSplash")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    )
                
                // Welcome Back Text
                VStack(spacing: 16) {
                    Text("Welcome back!")
                        .font(.radioCanadaBig(32, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    
                    Text("You've successfully rejoined your family")
                        .font(.radioCanadaBig(18, weight: .regular))
                        .foregroundColor(.black.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            Spacer()
            
            // Next Button
            Button(action: onNext) {
                HStack(spacing: 12) {
                    Text("Next")
                        .font(.radioCanadaBig(18, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .primaryAButtonStyle()
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.vibrantYellow)
        .ignoresSafeArea()
    }
}

// MARK: - Welcome to Family View (Legacy - keeping for backward compatibility)
struct WelcomeToFamilyView: View {
    let familyName: String
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Welcome Icon
            Image(systemName: "house.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            // Welcome Text
            VStack(spacing: 16) {
                Text("Welcome to Located!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("You're now part of the following family:")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(familyName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Spacer()
            
            // Next Button
            Button(action: onNext) {
                HStack {
                    Text("Next")
                    Image(systemName: "arrow.right")
                }
            }
            .primaryAButtonStyle()
            .padding(.bottom)
        }
        .padding()
    }
}

// MARK: - Child Invitation Prompt View
struct ChildInvitationPromptView: View {
    @StateObject private var invitationService = FamilyInvitationService()
    @State private var showingAcceptInvitation = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "envelope.badge")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Join Your Family")
                        .font(.headline)
                    Text("Your parent has invited you to join your family on Located")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Join") {
                    showingAcceptInvitation = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .sheet(isPresented: $showingAcceptInvitation) {
            AcceptFamilyInvitationView()
                .environmentObject(FamilyService())
        }
    }
}

#Preview {
    AcceptFamilyInvitationView()
        .environmentObject(FamilyService())
}
