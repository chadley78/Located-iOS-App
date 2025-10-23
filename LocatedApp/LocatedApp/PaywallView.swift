import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var canDismiss: Bool = false // Set to true if presenting modally
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                AppColors.accent
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 12) {
                            Text("1 Year Located Subscription")
                                .font(.radioCanadaBig(28, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Always know where your children are for the next 12 months")
                                .font(.radioCanadaBig(16))
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        
                        // Features
                        VStack(alignment: .leading, spacing: 20) {
                            FeatureRow(
                                icon: "location.fill",
                                title: "Real-Time Location",
                                description: "See where your family members are at all times"
                            )
                            
                            FeatureRow(
                                icon: "map.circle.fill",
                                title: "Geofence Alerts",
                                description: "Get notified when family members arrive or leave locations"
                            )
                            
                            FeatureRow(
                                icon: "person.3.fill",
                                title: "Unlimited Family Members",
                                description: "Add as many parents and children as you need"
                            )
                            
                            FeatureRow(
                                icon: "clock.fill",
                                title: "Location History",
                                description: "View past locations and movement patterns"
                            )
                        }
                        .padding(.horizontal, 30)
                        
                        // Subscription packages
                        if !subscriptionService.availablePackages.isEmpty {
                            VStack(spacing: 16) {
                                ForEach(subscriptionService.availablePackages, id: \.identifier) { package in
                                    PackageCard(
                                        package: package,
                                        isSelected: selectedPackage?.identifier == package.identifier,
                                        onSelect: {
                                            selectedPackage = package
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 30)
                        }
                        
                        // Subscription Information (Required by Apple)
                        if let package = selectedPackage {
                            VStack(spacing: 8) {
                                Text("Subscription Details")
                                    .font(.radioCanadaBig(16, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                
                                VStack(spacing: 4) {
                                    Text("• Auto-renewing subscription")
                                    Text("• Length: 1 Year")
                                    Text("• Price: \(package.localizedPriceString)")
                                    Text("• Price per month: \(getPricePerMonth(package))")
                                }
                                .font(.radioCanadaBig(14))
                                .foregroundColor(AppColors.textPrimary)
                            }
                            .padding(.horizontal, 30)
                        }
                        
                        // Subscribe button
                        Button(action: subscribeTapped) {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(getButtonText())
                            }
                        }
                        .primaryAButtonStyle()
                        .disabled(isPurchasing || selectedPackage == nil)
                        .padding(.horizontal, 30)
                        
                        // Restore purchases
                        Button(action: restorePurchases) {
                            Text("Restore Purchases")
                                .font(.radioCanadaBig(14))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .disabled(isPurchasing)
                        
                        // Sign out link
                        Button(action: {
                            Task {
                                await authService.signOut()
                            }
                        }) {
                            Text("Sign Out")
                                .font(.radioCanadaBig(14))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        // Terms and privacy
                        HStack(spacing: 4) {
                            Link("Terms of Service", destination: URL(string: "https://locatedapp.info/terms")!)
                            Text("•")
                            Link("Privacy Policy", destination: URL(string: "https://locatedapp.info/privacy-policy")!)
                        }
                        .font(.radioCanadaBig(12))
                        .foregroundColor(AppColors.textPrimary)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if canDismiss {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            await subscriptionService.fetchOfferings()
            // Auto-select first package if available
            if selectedPackage == nil, let firstPackage = subscriptionService.availablePackages.first {
                selectedPackage = firstPackage
            }
        }
    }
    
    private func getButtonText() -> String {
        guard let package = selectedPackage else {
            return "Select a Plan"
        }
        
        if let intro = package.storeProduct.introductoryDiscount,
           intro.paymentMode == .freeTrial {
            return "Start 7-Day Free Trial"
        } else {
            return "Subscribe Now"
        }
    }
    
    private func getPricePerMonth(_ package: Package) -> String {
        // Calculate price per month for annual subscription
        let price = package.storeProduct.price
        let pricePerMonth = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(floatLiteral: pricePerMonth)) ?? "N/A"
    }
    
    private func subscribeTapped() {
        guard let package = selectedPackage else { return }
        
        isPurchasing = true
        
        Task {
            let success = await subscriptionService.purchasePackage(package)
            
            await MainActor.run {
                isPurchasing = false
                
                if success {
                    // Purchase successful, dismiss paywall
                    if canDismiss {
                        dismiss()
                    }
                } else if let error = subscriptionService.errorMessage {
                    errorMessage = error
                    showingError = true
                }
            }
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        
        Task {
            let success = await subscriptionService.restorePurchases()
            
            await MainActor.run {
                isPurchasing = false
                
                if success {
                    // Restore successful
                    if canDismiss {
                        dismiss()
                    }
                } else {
                    errorMessage = subscriptionService.errorMessage ?? "No purchases found to restore"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.radioCanadaBig(16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(.radioCanadaBig(14))
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }
}

// MARK: - Package Card

struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.radioCanadaBig(18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let intro = package.storeProduct.introductoryDiscount,
                       intro.paymentMode == .freeTrial {
                        Text("7-day free trial, then \(package.localizedPriceString)")
                            .font(.radioCanadaBig(14))
                            .foregroundColor(AppColors.textPrimary)
                    } else {
                        Text(package.localizedPriceString)
                            .font(.radioCanadaBig(14))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: isSelected ? AppColors.textPrimary.opacity(0.3) : Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.textPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    PaywallView(canDismiss: true)
        .environmentObject(SubscriptionService())
}

