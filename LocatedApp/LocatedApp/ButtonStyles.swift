import SwiftUI

// MARK: - Primary A Button Style (Main Action Buttons)
// Uses theme colors: primary background with white text
struct PrimaryAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.radioCanadaBigButton)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppColors.primary)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .padding(.horizontal, 30)
    }
}

// MARK: - Primary B Button Style (Secondary Action Buttons)
// Uses theme colors: accent background with black text
struct PrimaryBButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.radioCanadaBigButton)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppColors.accent)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .padding(.horizontal, 30)
    }
}

// MARK: - Convenience Extensions
extension View {
    func primaryAButtonStyle() -> some View {
        self.buttonStyle(PrimaryAButtonStyle())
    }
    
    func primaryBButtonStyle() -> some View {
        self.buttonStyle(PrimaryBButtonStyle())
    }
}