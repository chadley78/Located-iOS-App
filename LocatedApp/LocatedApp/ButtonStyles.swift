import SwiftUI

// MARK: - Primary A Button Style (Blue Buttons) - Main Action Buttons
struct PrimaryAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .padding(.horizontal, 30)
    }
}

// MARK: - Primary B Button Style (Red Buttons) - Destructive/Action Buttons
struct PrimaryBButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.red)
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
