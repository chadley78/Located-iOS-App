import SwiftUI

struct SubscriptionManagementView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var familyService: FamilyService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var showPaywall = false
    @State private var isRestoring = false
    
    var body: some View {
        List {
            // Subscription Status Section
            Section {
                if let info = subscriptionService.subscriptionInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Status")
                                .font(.radioCanadaBig(14))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            StatusBadge(status: info.status)
                        }
                        
                        if let expiresAt = info.expiresAt {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(info.status == .trial ? "Trial Ends" : "Renews")
                                    .font(.radioCanadaBig(14))
                                    .foregroundColor(.secondary)
                                
                                Text(formatDate(expiresAt))
                                    .font(.radioCanadaBig(16, weight: .medium))
                                
                                if let days = info.daysRemaining, days > 0 {
                                    Text("\(days) days remaining")
                                        .font(.radioCanadaBig(12))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Active Subscription")
                                .font(.radioCanadaBig(16, weight: .medium))
                            
                            Text("Subscribe to continue using Located")
                                .font(.radioCanadaBig(14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        StatusBadge(status: .expired)
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Subscription")
            }
            
            // Actions Section
            Section {
                // Only show subscribe/upgrade if user is family creator
                if isCurrentUserCreator() {
                    if subscriptionService.subscriptionInfo?.isActive == true {
                        Button(action: {
                            Task {
                                await subscriptionService.openSubscriptionManagement()
                            }
                        }) {
                            Label("Manage Subscription", systemImage: "gear")
                        }
                    } else {
                        Button(action: {
                            showPaywall = true
                        }) {
                            Label("Subscribe Now", systemImage: "star.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button(action: restorePurchases) {
                        HStack {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                            
                            if isRestoring {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoring)
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        
                        Text("Only \(getCreatorName()) can manage the subscription")
                            .font(.radioCanadaBig(14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Actions")
            }
            
            // Plan Details Section
            if let info = subscriptionService.subscriptionInfo,
               info.isActive,
               let productId = info.productIdentifier {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan")
                            .font(.radioCanadaBig(14))
                            .foregroundColor(.secondary)
                        
                        Text(getPlanName(productId))
                            .font(.radioCanadaBig(16, weight: .medium))
                        
                        if info.willRenew {
                            Text("Auto-renewing")
                                .font(.radioCanadaBig(14))
                                .foregroundColor(.green)
                        } else {
                            Text("Expires at end of period")
                                .font(.radioCanadaBig(14))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Plan Details")
                }
            }
            
            // Family Info Section
            if let family = familyService.currentFamily {
                Section {
                    HStack {
                        Text("Family")
                        Spacer()
                        Text(family.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Members")
                        Spacer()
                        Text("\(family.members.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(formatDate(family.createdAt))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Family Information")
                }
            }
        }
        .navigationTitle("Subscription")
        .sheet(isPresented: $showPaywall) {
            PaywallView(canDismiss: true)
                .environmentObject(subscriptionService)
                .environmentObject(authService)
                .environmentObject(familyService)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isCurrentUserCreator() -> Bool {
        guard let userId = authService.currentUser?.id,
              let family = familyService.currentFamily else {
            return false
        }
        return family.createdBy == userId
    }
    
    private func getCreatorName() -> String {
        guard let family = familyService.currentFamily,
              let creatorMember = family.members[family.createdBy] else {
            return "the family admin"
        }
        return creatorMember.name
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func getPlanName(_ productId: String) -> String {
        if productId.contains("monthly") {
            return "Monthly Plan"
        } else if productId.contains("annual") {
            return "Annual Plan"
        } else {
            return "Premium Plan"
        }
    }
    
    private func restorePurchases() {
        isRestoring = true
        
        Task {
            let success = await subscriptionService.restorePurchases()
            
            await MainActor.run {
                isRestoring = false
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: SubscriptionStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.radioCanadaBig(12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(12)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .trial:
            return Color.blue.opacity(0.2)
        case .active:
            return Color.green.opacity(0.2)
        case .expired, .canceled:
            return Color.red.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .trial:
            return .blue
        case .active:
            return .green
        case .expired, .canceled:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SubscriptionManagementView()
            .environmentObject(SubscriptionService())
            .environmentObject(FamilyService())
            .environmentObject(AuthenticationService())
    }
}

