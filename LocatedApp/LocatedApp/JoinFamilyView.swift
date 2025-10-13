import SwiftUI
import FirebaseAuth

// MARK: - Join Family View (for Parents)
struct JoinFamilyView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var familyService: FamilyService
    @StateObject private var invitationService = FamilyInvitationService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    @State private var joinedFamilyName: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if !showingSuccess {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.crop.square.stack")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                            
                            Text("Join a Family")
                                .font(.radioCanadaBig(28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Enter the invitation code from another parent to join their family group.")
                                .font(.radioCanadaBig(16, weight: .regular))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Invitation Code Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invitation Code")
                                .font(.radioCanadaBig(16, weight: .medium))
                                .foregroundColor(.white)
                            
                            TextField("e.g., ABC123", text: $inviteCode)
                                .padding(12)
                                .background(Color.familyMembersBg)
                                .cornerRadius(8)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                        }
                        .padding(.horizontal)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.radioCanadaBig(12, weight: .regular))
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        // Join Family Button
                        Button(action: joinFamily) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Join Family")
                                }
                            }
                        }
                        .primaryAButtonStyle()
                        .disabled(inviteCode.isEmpty || isLoading)
                        
                        // Cancel Button
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.radioCanadaBig(14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom)
                    } else {
                        // Success State
                        VStack(spacing: 24) {
                            // Success Icon
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                            
                            Text("Welcome!")
                                .font(.radioCanadaBig(32, weight: .bold))
                                .foregroundColor(.white)
                            
                            if let familyName = joinedFamilyName {
                                Text("You've successfully joined '\(familyName)'")
                                    .font(.radioCanadaBig(18, weight: .regular))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            } else {
                                Text("You've successfully joined the family")
                                    .font(.radioCanadaBig(18, weight: .regular))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Spacer()
                            
                            Button("Continue") {
                                // Refresh family data
                                Task {
                                    await familyService.forceRefreshFamilyListener()
                                    dismiss()
                                }
                            }
                            .primaryAButtonStyle()
                            .padding(.bottom)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .background(Color.vibrantPurple)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func joinFamily() {
        guard !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter an invitation code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await invitationService.acceptInvitation(
                    inviteCode: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                )
                
                // Try to get the family name from the result or familyService
                let familyId = result["familyId"] as? String
                
                await MainActor.run {
                    self.isLoading = false
                    self.showingSuccess = true
                }
                
                // Refresh family data to get the family name
                if let familyId = familyId {
                    await familyService.forceRefreshFamilyListener()
                    await MainActor.run {
                        self.joinedFamilyName = familyService.currentFamily?.name
                    }
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

#Preview {
    JoinFamilyView()
        .environmentObject(AuthenticationService())
        .environmentObject(FamilyService())
}


