import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Family Setup View
struct FamilySetupView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var familyService = FamilyService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var familyName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Create Your Family")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Set up your family group to start tracking your children's locations and creating geofences.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Family Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Family Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("e.g., The Smith Family", text: $familyName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
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
                
                // Create Family Button
                Button(action: createFamily) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "house.fill")
                        }
                        Text(isLoading ? "Creating Family..." : "Create Family")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(familyName.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(familyName.isEmpty || isLoading)
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
            .navigationTitle("Family Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
            .alert("Family Created!", isPresented: $showingSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text("Your family '\(familyName)' has been created successfully. You can now invite your children to join.")
            }
        }
    }
    
    private func createFamily() {
        guard !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a family name"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let familyId = try await familyService.createFamily(name: familyName.trimmingCharacters(in: .whitespacesAndNewlines))
                print("✅ Family created successfully with ID: \(familyId)")
                
                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
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

// MARK: - Family Management View
struct FamilyManagementView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var familyService = FamilyService()
    @State private var showingInviteChild = false
    @State private var showingFamilySettings = false
    @Environment(\.dismiss) private var dismiss
    
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
                    
                    // Family Members
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Family Members")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(familyService.getFamilyMembers(), id: \.0) { userId, member in
                            FamilyMemberRow(userId: userId, member: member)
                        }
                    }
                    
                    Spacer()
                    
                    // Actions
                    VStack(spacing: 12) {
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
                        
                        Button(action: {
                            showingFamilySettings = true
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Family Settings")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
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
                        
                        Button("Create Family") {
                            // This will be handled by the parent view
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
                }
            }
            .padding()
            .navigationTitle("Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingInviteChild) {
                InviteChildView()
                    .environmentObject(familyService)
            }
            .sheet(isPresented: $showingFamilySettings) {
                FamilySettingsView()
                    .environmentObject(familyService)
            }
        }
    }
}

// MARK: - Family Member Row
struct FamilyMemberRow: View {
    let userId: String
    let member: FamilyMember
    
    var body: some View {
        HStack {
            Image(systemName: member.role == .parent ? "person.fill" : "person")
                .foregroundColor(member.role == .parent ? .blue : .green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.headline)
                
                Text(member.role.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatJoinDate(member.joinedAt))
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Navigation indicator for children
            if member.role == .child {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private func formatJoinDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Invite Child View
struct InviteChildView: View {
    @EnvironmentObject var familyService: FamilyService
    @StateObject private var invitationService = FamilyInvitationService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var childName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    @State private var inviteCode: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Invite Your Child")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Enter your child's name to generate an invitation code they can use to join your family.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Child Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Child's Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("e.g., Emma Smith", text: $childName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal)
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                // Success State
                if let inviteCode = inviteCode {
                    VStack(spacing: 16) {
                        Text("Invitation Created!")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Text("Share this code with your child:")
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
                                // Share invitation with deep link
                                let deepLink = invitationService.generateInvitationLink(inviteCode: inviteCode)
                                let universalLink = invitationService.generateUniversalLink(inviteCode: inviteCode)
                                let shareText = "Join my family on Located! Use this code: \(inviteCode)\n\nOr click this link: \(deepLink)\n\nIf the link doesn't work, use this: \(universalLink)"
                                
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
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Create Invitation Button
                Button(action: createInvitation) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "qrcode")
                        }
                        Text(isLoading ? "Creating Invitation..." : "Create Invitation")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(childName.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(childName.isEmpty || isLoading)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Invite Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createInvitation() {
        guard !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your child's name"
            return
        }
        
        guard let family = familyService.currentFamily else {
            errorMessage = "No family found"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let inviteCode = try await invitationService.createInvitation(
                    familyId: family.id,
                    childName: childName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    self.inviteCode = inviteCode
                    self.isLoading = false
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

// MARK: - Family Settings View
struct FamilySettingsView: View {
    @EnvironmentObject var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss
    @State private var familyName = ""
    @State private var isEditingName = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let family = familyService.currentFamily {
                    // Family Name Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Family Name")
                            .font(.headline)
                        
                        HStack {
                            if isEditingName {
                                TextField("Family Name", text: $familyName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit {
                                        saveFamilyName()
                                    }
                                
                                Button("Save") {
                                    saveFamilyName()
                                }
                                .foregroundColor(.blue)
                                .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                Button("Cancel") {
                                    cancelEditing()
                                }
                                .foregroundColor(.red)
                            } else {
                                Text(family.name)
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button("Edit") {
                                    startEditing()
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                } else {
                    Text("No family found")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Family Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let family = familyService.currentFamily {
                familyName = family.name
            }
        }
    }
    
    private func startEditing() {
        isEditingName = true
        errorMessage = nil
    }
    
    private func cancelEditing() {
        isEditingName = false
        if let family = familyService.currentFamily {
            familyName = family.name
        }
        errorMessage = nil
    }
    
    private func saveFamilyName() {
        let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Family name cannot be empty"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await familyService.updateFamilyName(trimmedName)
                await MainActor.run {
                    isEditingName = false
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
