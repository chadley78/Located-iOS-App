import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Accept Family Invitation View
struct AcceptFamilyInvitationView: View {
    @StateObject private var invitationService = FamilyInvitationService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
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
                
                // Success Message
                if showingSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Welcome to Your Family!")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Text(successMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
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
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(inviteCode.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(inviteCode.isEmpty || isLoading)
                .padding(.horizontal)
                
                // Skip Button
                Button("Skip for now") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
            .padding()
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
                    self.showingSuccess = true
                    self.successMessage = "You've successfully joined your family! You can now share your location and receive geofence notifications."
                }
                
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    dismiss()
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
        }
    }
}

#Preview {
    AcceptFamilyInvitationView()
}
