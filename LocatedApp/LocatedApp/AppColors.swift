import SwiftUI

// MARK: - App Color Palette
// Centralized color definitions - original vibrant design
struct AppColors {
    // MARK: - Brand Colors
    static let primary = Color(red: 1.0, green: 0.35, blue: 0.37) // #FF595E - vibrantRed (main CTAs)
    static let accent = Color(red: 1.0, green: 0.79, blue: 0.23) // #FFCA3A - vibrantYellow (backgrounds, highlights)
    static let success = Color(red: 0.54, green: 0.79, blue: 0.15) // #8AC926 - vibrantGreen
    static let info = Color(red: 0.10, green: 0.51, blue: 0.77) // #1982C4 - vibrantBlue
    static let highlight = Color(red: 0.42, green: 0.30, blue: 0.58) // #6A4C93 - vibrantPurple
    
    // MARK: - Surface Colors
    static let surface1 = Color(red: 0.88, green: 0.84, blue: 0.94) // #E1D5F0 - familyMembersBg
    static let surface2 = Color(red: 0.89, green: 0.97, blue: 0.79) // #E4F8C9 - locationAlertsBg
    static let surface3 = Color(red: 0.80, green: 0.91, blue: 0.98) // #CBE9FB - settingsBg
    
    // MARK: - Text Colors
    static let textPrimary = Color.primary // System primary (adapts to light/dark mode)
    static let textSecondary = Color.secondary // System secondary gray
    
    // MARK: - Utility Colors
    static let successDark = Color(red: 0.35, green: 0.55, blue: 0.10) // #5A8A1A - darker green for text
    static let errorColor = Color.red // System red for errors
    static let warningColor = Color.orange // System orange for warnings
    
    // MARK: - Overlay Colors
    static let overlayLight = Color.white
    static let overlayDark = Color.black
    
    // MARK: - System Color Semantic Mappings (for migration)
    static let systemBlue = Color.blue
    static let systemGreen = Color.green
    static let systemRed = Color.red
    static let systemGray = Color.gray
    static let systemBackground = Color(UIColor.systemBackground)
    static let surfaceGray = Color(UIColor.systemGray6)
    
    // MARK: - Legacy Color Names (for backward compatibility during migration)
    static let vibrantRed = primary
    static let vibrantYellow = accent
    static let vibrantGreen = success
    static let vibrantBlue = info
    static let vibrantPurple = highlight
    static let vibrantGreenDark = successDark
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

