import SwiftUI

// MARK: - Custom Navigation Bar
struct CustomNavigationBar: View {
    let title: String
    let backgroundColor: Color
    let leadingButton: NavigationButton?
    let trailingButton: NavigationButton?
    
    struct NavigationButton {
        let title: String
        let action: () -> Void
        let isDisabled: Bool
        
        init(title: String, isDisabled: Bool = false, action: @escaping () -> Void) {
            self.title = title
            self.isDisabled = isDisabled
            self.action = action
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea(edges: .top)
            
            // Navigation Bar Content
            HStack {
                // Leading Button
                if let leadingButton = leadingButton {
                    Button(action: leadingButton.action) {
                        Text(leadingButton.title)
                            .font(.radioCanadaBig(17, weight: .regular))
                            .foregroundColor(AppColors.overlayLight)
                    }
                    .disabled(leadingButton.isDisabled)
                    .opacity(leadingButton.isDisabled ? 0.5 : 1.0)
                } else {
                    Spacer()
                        .frame(width: 60)
                }
                
                Spacer()
                
                // Title
                Text(title)
                    .font(.radioCanadaBig(17, weight: .semibold))
                    .foregroundColor(AppColors.overlayLight)
                
                Spacer()
                
                // Trailing Button
                if let trailingButton = trailingButton {
                    Button(action: trailingButton.action) {
                        Text(trailingButton.title)
                            .font(.radioCanadaBig(17, weight: .semibold))
                            .foregroundColor(AppColors.overlayLight)
                    }
                    .disabled(trailingButton.isDisabled)
                    .opacity(trailingButton.isDisabled ? 0.5 : 1.0)
                } else {
                    Spacer()
                        .frame(width: 60)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
        }
        .frame(height: 44)
    }
}

// MARK: - Custom Navigation Container
struct CustomNavigationContainer<Content: View>: View {
    let title: String
    let backgroundColor: Color
    let leadingButton: CustomNavigationBar.NavigationButton?
    let trailingButton: CustomNavigationBar.NavigationButton?
    let content: Content
    
    init(
        title: String,
        backgroundColor: Color,
        leadingButton: CustomNavigationBar.NavigationButton? = nil,
        trailingButton: CustomNavigationBar.NavigationButton? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.leadingButton = leadingButton
        self.trailingButton = trailingButton
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            CustomNavigationBar(
                title: title,
                backgroundColor: backgroundColor,
                leadingButton: leadingButton,
                trailingButton: trailingButton
            )
            
            content
        }
        .background(backgroundColor.ignoresSafeArea())
    }
}

