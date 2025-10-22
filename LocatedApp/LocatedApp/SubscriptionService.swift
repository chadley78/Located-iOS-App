import Foundation
import RevenueCat
import FirebaseAuth
import FirebaseFirestore

// MARK: - Subscription Models

// Note: SubscriptionStatus is defined in FamilyModels.swift

struct SubscriptionInfo {
    let status: SubscriptionStatus
    let expiresAt: Date?
    let willRenew: Bool
    let productIdentifier: String?
    
    var isActive: Bool {
        status == .trial || status == .active
    }
    
    var daysRemaining: Int? {
        guard let expiresAt = expiresAt else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: expiresAt).day
        return max(0, days ?? 0)
    }
}

// MARK: - Subscription Service

@MainActor
class SubscriptionService: ObservableObject {
    @Published var subscriptionInfo: SubscriptionInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var availablePackages: [Package] = []
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    // Configuration - RevenueCat API key
    private let revenueCatAPIKey = "appl_BzdMszzsXGmbrHCdlMJxdKkpFUg"
    
    init() {
        print("🔐 SubscriptionService initialized")
    }
    
    /// Configure RevenueCat SDK - call this on app launch
    func configure() {
        print("🔐 Configuring RevenueCat SDK")
        
        // Configure RevenueCat
        Purchases.logLevel = .info // Production setting
        Purchases.configure(withAPIKey: revenueCatAPIKey)
        
        print("✅ RevenueCat SDK configured")
    }
    
    /// Set the user ID for RevenueCat (call after authentication)
    func identifyUser(userId: String) async {
        print("🔐 Identifying user in RevenueCat: \(userId)")
        
        do {
            _ = try await Purchases.shared.logIn(userId)
            print("✅ User identified in RevenueCat")
            
            // Sync Firestore trial info to RevenueCat attributes
            await syncFirestoreTrialToRevenueCat(userId: userId)
            
            // Check subscription status after identifying
            await checkSubscriptionStatus()
        } catch {
            print("❌ Error identifying user in RevenueCat: \(error)")
            errorMessage = "Failed to verify subscription: \(error.localizedDescription)"
            
            // Ensure loading state is cleared even on error
            isLoading = false
        }
    }
    
    /// Check current subscription status
    func checkSubscriptionStatus() async {
        print("🔐 Checking subscription status")
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            await processCustomerInfo(customerInfo)
        } catch {
            print("❌ Error checking subscription status: \(error)")
            errorMessage = "Failed to check subscription: \(error.localizedDescription)"
        }
        
        // Always clear loading state
        isLoading = false
        print("🔐 Subscription status check complete, isLoading = false")
    }
    
    /// Process customer info and update subscription status
    private func processCustomerInfo(_ customerInfo: CustomerInfo) async {
        print("🔐 Processing customer info")
        print("🔐 Active entitlements: \(customerInfo.entitlements.active.keys)")
        print("🔐 All entitlements: \(customerInfo.entitlements.all.keys)")
        
        // Check for active entitlements
        if let entitlement = customerInfo.entitlements.active["premium"] {
            // User has active subscription
            let willRenew = entitlement.willRenew
            let expiresAt = entitlement.expirationDate
            let productId = entitlement.productIdentifier
            
            // Determine status
            let status: SubscriptionStatus
            if entitlement.periodType == .trial {
                status = .trial
            } else if willRenew {
                status = .active
            } else {
                status = .canceled // Active but won't renew
            }
            
            subscriptionInfo = SubscriptionInfo(
                status: status,
                expiresAt: expiresAt,
                willRenew: willRenew,
                productIdentifier: productId
            )
            
            print("✅ Subscription active: \(status.displayName), expires: \(expiresAt?.description ?? "N/A")")
            
            // Sync to Firestore for cross-platform access
            await syncSubscriptionToFirestore()
            
        } else {
            // No active subscription
            subscriptionInfo = SubscriptionInfo(
                status: .expired,
                expiresAt: nil,
                willRenew: false,
                productIdentifier: nil
            )
            
            print("ℹ️ No active subscription")
            
            // Clear Firestore subscription data
            await syncSubscriptionToFirestore()
        }
    }
    
    /// Fetch available subscription packages
    func fetchOfferings() async {
        print("🔐 Fetching available offerings")
        isLoading = true
        errorMessage = nil
        
        do {
            let offerings = try await Purchases.shared.offerings()
            
            if let current = offerings.current, !current.availablePackages.isEmpty {
                availablePackages = current.availablePackages
                print("✅ Found \(availablePackages.count) available packages")
            } else {
                print("⚠️ No offerings available")
                errorMessage = "No subscription plans available"
            }
            
            isLoading = false
        } catch {
            print("❌ Error fetching offerings: \(error)")
            errorMessage = "Failed to load subscription plans: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Purchase a subscription package
    func purchasePackage(_ package: Package) async -> Bool {
        print("🔐 Purchasing package: \(package.storeProduct.localizedTitle)")
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            // Process the purchase result
            await processCustomerInfo(result.customerInfo)
            
            if result.userCancelled {
                print("ℹ️ User cancelled purchase")
                isLoading = false
                return false
            }
            
            print("✅ Purchase successful")
            isLoading = false
            return true
            
        } catch {
            print("❌ Error purchasing package: \(error)")
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    /// Restore previous purchases
    func restorePurchases() async -> Bool {
        print("🔐 Restoring purchases")
        isLoading = true
        errorMessage = nil
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await processCustomerInfo(customerInfo)
            
            if subscriptionInfo?.isActive == true {
                print("✅ Purchases restored successfully")
                isLoading = false
                return true
            } else {
                print("ℹ️ No active purchases found to restore")
                errorMessage = "No active subscription found"
                isLoading = false
                return false
            }
            
        } catch {
            print("❌ Error restoring purchases: \(error)")
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    /// Check if user has active subscription or trial
    func isSubscriptionActive() -> Bool {
        return subscriptionInfo?.isActive ?? false
    }
    
    /// Sync Firestore trial information to RevenueCat as custom attributes
    /// This allows viewing trial status in RevenueCat dashboard
    private func syncFirestoreTrialToRevenueCat(userId: String) async {
        do {
            // Get user document to find familyId
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let familyId = userDoc.data()?["familyId"] as? String else {
                print("ℹ️ Cannot sync trial to RevenueCat: user has no familyId")
                return
            }
            
            // Get family document to check trial status
            let familyDoc = try await db.collection("families").document(familyId).getDocument()
            guard let familyData = familyDoc.data() else {
                print("ℹ️ Cannot sync trial to RevenueCat: no family data")
                return
            }
            
            // Build custom attributes for RevenueCat
            var attributes: [String: String] = [:]
            
            if let status = familyData["subscriptionStatus"] as? String {
                attributes["subscription_status"] = status
            }
            
            if let trialEndsAt = (familyData["trialEndsAt"] as? Timestamp)?.dateValue() {
                let formatter = ISO8601DateFormatter()
                attributes["trial_ends_at"] = formatter.string(from: trialEndsAt)
                
                // Calculate days remaining
                let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: trialEndsAt).day ?? 0
                attributes["trial_days_remaining"] = String(max(0, daysRemaining))
            }
            
            if let familyName = familyData["name"] as? String {
                attributes["family_name"] = familyName
            }
            
            attributes["family_id"] = familyId
            
            // Check if user is family creator
            let isCreator = familyData["createdBy"] as? String == userId
            attributes["is_family_creator"] = isCreator ? "true" : "false"
            
            // Set attributes in RevenueCat
            Purchases.shared.attribution.setAttributes(attributes)
            
            print("✅ Synced trial info to RevenueCat attributes: \(attributes)")
            
        } catch {
            print("❌ Error syncing trial to RevenueCat: \(error)")
        }
    }
    
    /// Sync subscription status to Firestore (for cross-platform access)
    func syncSubscriptionToFirestore() async {
        guard let userId = auth.currentUser?.uid else {
            print("ℹ️ Cannot sync subscription: no authenticated user")
            return
        }
        
        do {
            // Get user document to find familyId
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let familyId = userDoc.data()?["familyId"] as? String else {
                print("ℹ️ Cannot sync subscription: user has no familyId")
                return
            }
            
            // Check if user is the family creator (only creator's subscription matters)
            let familyDoc = try await db.collection("families").document(familyId).getDocument()
            guard let familyData = familyDoc.data(),
                  let createdBy = familyData["createdBy"] as? String,
                  createdBy == userId else {
                print("ℹ️ Skipping sync: user is not family creator")
                return
            }
            
            print("🔐 Syncing subscription to Firestore for family: \(familyId)")
            
            var updateData: [String: Any] = [:]
            
            if let info = subscriptionInfo, info.isActive {
                // Only update if there's an active RevenueCat subscription
                updateData["subscriptionStatus"] = info.status.rawValue
                
                if let expiresAt = info.expiresAt {
                    updateData["subscriptionExpiresAt"] = expiresAt
                }
                
                if info.status == .trial, let expiresAt = info.expiresAt {
                    updateData["trialEndsAt"] = expiresAt
                }
                
                try await db.collection("families").document(familyId).updateData(updateData)
                print("✅ Subscription synced to Firestore")
            } else {
                // Don't overwrite Firestore trial - only update when there's an active RevenueCat subscription
                // The Firestore-based 7-day trial should remain until it naturally expires
                print("ℹ️ No active RevenueCat subscription - preserving Firestore trial status")
            }
            
        } catch {
            print("❌ Error syncing subscription to Firestore: \(error)")
            // Don't throw - this is a background sync operation
        }
    }
    
    /// Get formatted expiration date string
    func getExpirationDateString() -> String? {
        guard let expiresAt = subscriptionInfo?.expiresAt else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: expiresAt)
    }
    
    /// Present subscription management in App Store
    func openSubscriptionManagement() async {
        do {
            try await Purchases.shared.showManageSubscriptions()
            print("✅ Opened subscription management")
        } catch {
            print("❌ Error opening subscription management: \(error)")
            errorMessage = "Failed to open subscription settings"
        }
    }
}

// Note: In RevenueCat 5.x, we manually check subscription status rather than using delegates
// This avoids NSObject inheritance requirements and works better with SwiftUI's @MainActor

