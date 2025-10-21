import SwiftUI

// MARK: - Subscription Gate View Modifier

struct SubscriptionGate: ViewModifier {
    // Injected directly instead of using @EnvironmentObject
    @ObservedObject var subscriptionService: SubscriptionService
    @ObservedObject var familyService: FamilyService
    @ObservedObject var authService: AuthenticationService
    
    @State private var showPaywall = false
    @State private var shouldShowGateState = false
    @State private var isCreator = false
    @State private var creatorName = "the family admin"
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            // Show gate if subscription expired
            if shouldShowGateState {
                SubscriptionGateView(
                    isCreator: isCreator,
                    creatorName: creatorName,
                    onUpgrade: {
                        showPaywall = true
                    }
                )
            }
        }
        .onAppear {
            updateGateState()
        }
        .onChange(of: subscriptionService.isLoading) { _ in
            updateGateState()
        }
        .onChange(of: familyService.currentFamily?.id) { _ in
            updateGateState()
        }
        .onChange(of: familyService.currentFamily?.subscriptionStatus) { _ in
            updateGateState()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(canDismiss: false)
                .environmentObject(subscriptionService)
                .environmentObject(authService)
                .environmentObject(familyService)
        }
    }
    
    private func updateGateState() {
        shouldShowGateState = shouldShowGate()
        if shouldShowGateState {
            isCreator = isCurrentUserCreator()
            creatorName = getCreatorName()
        }
    }
    
    private func shouldShowGate() -> Bool {
        // Don't show if still loading
        guard !subscriptionService.isLoading else {
            print("🚪 Gate: Not showing - subscription service is loading")
            return false
        }
        
        // Check if family has active subscription
        guard let family = familyService.currentFamily else {
            print("🚪 Gate: Not showing - no family loaded")
            return false
        }
        
        // Check subscription status from family
        if let status = family.subscriptionStatus {
            let shouldShow = status == .expired || status == .canceled
            print("🚪 Gate: Family status = \(status), shouldShow = \(shouldShow)")
            return shouldShow
        }
        
        // Check trial expiration (Firestore-based trial)
        if let trialEndsAt = family.trialEndsAt {
            let isTrialExpired = trialEndsAt < Date()
            let hasActiveSubscription = subscriptionService.isSubscriptionActive()
            let shouldShow = isTrialExpired && !hasActiveSubscription
            print("🚪 Gate: Trial ends at \(trialEndsAt), expired = \(isTrialExpired), hasActiveSub = \(hasActiveSubscription), shouldShow = \(shouldShow)")
            return shouldShow
        }
        
        // Default to not showing gate if we can't determine
        print("🚪 Gate: Not showing - no subscription info available")
        return false
    }
    
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
}

// MARK: - Subscription Gate View

struct SubscriptionGateView: View {
    let isCreator: Bool
    let creatorName: String
    let onUpgrade: () -> Void
    
    var body: some View {
        ZStack {
            // Background color
            AppColors.accent
                .ignoresSafeArea()
            
            // Gate content
            VStack(spacing: 24) {
                // Title
                Text(isCreator ? "Trial Expired" : "Subscription Required")
                    .font(.radioCanadaBig(28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                // Message
                Text(getMessage())
                    .font(.radioCanadaBig(16))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Action button
                if isCreator {
                    Button(action: onUpgrade) {
                        Text("Choose Subscription")
                            .font(.radioCanadaBig(18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(AppColors.primary)
                            .cornerRadius(25)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Contact \(creatorName) to renew")
                            .font(.radioCanadaBig(14))
                            .foregroundColor(AppColors.textPrimary)
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func getMessage() -> String {
        if isCreator {
            return "Your free trial has ended. Upgrade now to continue using Located to keep your family safe and connected."
        } else {
            return "The family subscription has expired. Please ask \(creatorName) to renew the subscription to continue using Located."
        }
    }
}

// MARK: - View Extension

extension View {
    func subscriptionGate(
        subscriptionService: SubscriptionService,
        familyService: FamilyService,
        authService: AuthenticationService
    ) -> some View {
        self.modifier(SubscriptionGate(
            subscriptionService: subscriptionService,
            familyService: familyService,
            authService: authService
        ))
    }
}

// MARK: - Preview

#Preview("Creator View") {
    SubscriptionGateView(
        isCreator: true,
        creatorName: "John",
        onUpgrade: {}
    )
}

#Preview("Non-Creator View") {
    SubscriptionGateView(
        isCreator: false,
        creatorName: "Sarah",
        onUpgrade: {}
    )
}


