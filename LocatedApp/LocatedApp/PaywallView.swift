import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var canDismiss: Bool = false // Set to true if presenting modally
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.98, blue: 1.0), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            
                            Text("Upgrade to Premium")
                                .font(.radioCanadaBig(28, weight: .bold))
                            
                            Text("Keep your family connected and safe")
                                .font(.radioCanadaBig(16))
                                .foregroundColor(.secondary)
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
                        
                        // Subscribe button
                        Button(action: subscribeTapped) {
                            HStack {
                                if isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(getButtonText())
                                        .font(.radioCanadaBig(18, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(28)
                        }
                        .disabled(isPurchasing || selectedPackage == nil)
                        .opacity((isPurchasing || selectedPackage == nil) ? 0.6 : 1.0)
                        .padding(.horizontal, 30)
                        
                        // Restore purchases
                        Button(action: restorePurchases) {
                            Text("Restore Purchases")
                                .font(.radioCanadaBig(14))
                                .foregroundColor(.secondary)
                        }
                        .disabled(isPurchasing)
                        
                        // Terms and privacy
                        HStack(spacing: 4) {
                            Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                            Text("•")
                            Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                        }
                        .font(.radioCanadaBig(12))
                        .foregroundColor(.secondary)
                        
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
                .foregroundColor(.orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.radioCanadaBig(16, weight: .semibold))
                
                Text(description)
                    .font(.radioCanadaBig(14))
                    .foregroundColor(.secondary)
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
                        .foregroundColor(.primary)
                    
                    if let intro = package.storeProduct.introductoryDiscount,
                       intro.paymentMode == .freeTrial {
                        Text("7-day free trial, then \(package.localizedPriceString)")
                            .font(.radioCanadaBig(14))
                            .foregroundColor(.secondary)
                    } else {
                        Text(package.localizedPriceString)
                            .font(.radioCanadaBig(14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .orange : .gray)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: isSelected ? Color.orange.opacity(0.3) : Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
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

