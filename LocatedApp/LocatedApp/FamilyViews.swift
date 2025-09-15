import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

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
                // Call the Cloud Function to create invitation
                let functions = Functions.functions()
                let createInvitation = functions.httpsCallable("createInvitation")
                
                let result = try await createInvitation.call([
                    "familyId": family.id,
                    "childName": childName.trimmingCharacters(in: .whitespacesAndNewlines)
                ])
                
                if let data = result.data as? [String: Any],
                   let inviteCode = data["inviteCode"] as? String {
                    await MainActor.run {
                        self.inviteCode = inviteCode
                        self.isLoading = false
                    }
                } else {
                    throw NSError(domain: "InvitationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
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
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Family Settings")
                    .font(.title)
                    .padding()
                
                Text("Settings coming soon...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
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
    }
}
