import SwiftUI

// MARK: - Color Palette
extension Color {
    static let vibrantRed = Color(red: 1.0, green: 0.35, blue: 0.37) // #FF595E
    static let vibrantYellow = Color(red: 1.0, green: 0.79, blue: 0.23) // #FFCA3A
    static let vibrantGreen = Color(red: 0.54, green: 0.79, blue: 0.15) // #8AC926
    static let vibrantBlue = Color(red: 0.10, green: 0.51, blue: 0.77) // #1982C4
    static let vibrantPurple = Color(red: 0.42, green: 0.30, blue: 0.58) // #6A4C93
    
    // Button background colors
    static let familyMembersBg = Color(red: 0.88, green: 0.84, blue: 0.94) // #E1D5F0
    static let locationAlertsBg = Color(red: 0.89, green: 0.97, blue: 0.79) // #E4F8C9
    static let settingsBg = Color(red: 0.80, green: 0.91, blue: 0.98) // #CBE9FB
    
    // Darker text colors for better contrast
    static let vibrantGreenDark = Color(red: 0.35, green: 0.55, blue: 0.10) // #5A8A1A - darker shade of vibrant green
}

// MARK: - Primary A Button Style (Vibrant Red Buttons) - Main Action Buttons
struct PrimaryAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.radioCanadaBigButton)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.vibrantRed)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .padding(.horizontal, 30)
    }
}

// MARK: - Primary B Button Style (Vibrant Yellow Buttons) - Destructive/Action Buttons
struct PrimaryBButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.radioCanadaBigButton)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.vibrantYellow)
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