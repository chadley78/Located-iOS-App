import SwiftUI

// MARK: - Invitation Code Panel
struct InvitationCodePanel: View {
    let inviteCode: String
    let recipientName: String
    let shareText: String
    let onCopy: () -> Void
    
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Invitation Created!")
                .font(.radioCanadaBig(22, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Share this code with \(recipientName):")
                .font(.radioCanadaBig(16, weight: .regular))
                .foregroundColor(AppColors.textPrimary)
            
            // Invitation Code Display
            Text(inviteCode)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)
                .padding()
                .background(AppColors.invitationCodeBackground)
                .cornerRadius(8)
            
            Text("This code expires in 24 hours")
                .font(.radioCanadaBig(12, weight: .regular))
                .foregroundColor(AppColors.textPrimary)
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: onCopy) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.radioCanadaBig(12, weight: .regular))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white)
                    .cornerRadius(6)
                }
                
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.radioCanadaBig(12, weight: .regular))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white)
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(AppColors.invitationPanelBackground)
        .cornerRadius(12)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
    }
}

#Preview {
    InvitationCodePanel(
        inviteCode: "ABC123",
        recipientName: "Emma Smith",
        shareText: "Join my family on Located! Use this code: ABC123",
        onCopy: { print("Copy tapped") }
    )
    .padding()
}

