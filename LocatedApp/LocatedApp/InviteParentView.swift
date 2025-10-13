import SwiftUI
import FirebaseAuth

// MARK: - Invite Parent View
struct InviteParentView: View {
    @EnvironmentObject var familyService: FamilyService
    @StateObject private var invitationService = FamilyInvitationService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var parentName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var inviteCode: String?
    
    var body: some View {
        CustomNavigationContainer(
            title: "Invite Parent",
            backgroundColor: AppColors.highlight,
            leadingButton: CustomNavigationBar.NavigationButton(title: "Cancel") {
                dismiss()
            },
            trailingButton: CustomNavigationBar.NavigationButton(
                title: "Done",
                isDisabled: inviteCode == nil
            ) {
                dismiss()
            }
        ) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image("FlyingMotherNoBG")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                        
                        Text("Invite Another Parent")
                            .font(.radioCanadaBig(28, weight: .bold))
                            .foregroundColor(AppColors.overlayLight)
                        
                        Text("Enter a name or description for this parent to generate an invitation code.")
                            .font(.radioCanadaBig(16, weight: .regular))
                            .foregroundColor(AppColors.overlayLight)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Parent Name/Description Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parent Name/Description")
                            .font(.radioCanadaBig(16, weight: .medium))
                            .foregroundColor(AppColors.overlayLight)
                        
                        TextField("e.g., Mom, Dad, Guardian", text: $parentName)
                            .padding(12)
                            .background(AppColors.surface1)
                            .cornerRadius(8)
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(AppColors.errorColor)
                            .font(.radioCanadaBig(12, weight: .regular))
                            .padding(.horizontal)
                    }
                    
                    // Success State
                    if let inviteCode = inviteCode {
                        VStack(spacing: 16) {
                            Text("Invitation Created!")
                                .font(.radioCanadaBig(22, weight: .semibold))
                                .foregroundColor(AppColors.overlayLight)
                            
                            Text("Share this code with another parent:")
                                .font(.radioCanadaBig(16, weight: .regular))
                                .foregroundColor(AppColors.overlayLight)
                            
                            Text(inviteCode)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(AppColors.highlight)
                                .padding()
                                .background(AppColors.surface1)
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
                                    .foregroundColor(AppColors.overlayLight)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AppColors.overlayLight.opacity(0.2))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    // Share via system share sheet
                                    let text = "Join my family on Located! Use invitation code: \(inviteCode)"
                                    let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                                    
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first,
                                       let rootVC = window.rootViewController {
                                        rootVC.present(av, animated: true)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share")
                                    }
                                    .font(.radioCanadaBig(12, weight: .regular))
                                    .foregroundColor(AppColors.overlayLight)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AppColors.overlayLight.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.overlayLight.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        Spacer()
                        
                        // Generate Invitation Button
                        Button(action: createInvitation) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                HStack {
                                    Image(systemName: "qrcode")
                                    Text("Generate Invitation Code")
                                }
                            }
                        }
                        .primaryAButtonStyle()
                        .disabled(parentName.isEmpty || isLoading)
                    }
                }
                .padding()
            }
        }
    }
    
    private func createInvitation() {
        guard let familyId = familyService.currentFamily?.id else {
            errorMessage = "No family found"
            return
        }
        
        guard !parentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a name or description"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let code = try await invitationService.createInvitation(
                    familyId: familyId,
                    childName: parentName.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: .parent
                )
                
                await MainActor.run {
                    self.inviteCode = code
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    InviteParentView()
        .environmentObject(AuthenticationService())
        .environmentObject(FamilyService())
}


