import SwiftUI

// MARK: - App Color Palette
// New vibrant playful design - Purple/Pink/Yellow theme
struct AppColors {
    // MARK: - Core Palette
    static let primary = Color(hex: "#7B61FF")      // Primary brand color – main buttons and interactive elements
    static let secondary = Color(hex: "#F9A65A")    // Secondary color – accent icons, small highlights, or illustrations
    static let accent = Color(hex: "#FFE36E")       // Accent color – cheerful highlights and visual emphasis
    static let surface = Color(hex: "#FFFFFF")      // Surface color – cards, text fields, and modal backgrounds
    static let background = Color(hex: "#F2A6B5")   // Background color – soft pink backdrop for screens and sections
    static let highlight = Color(hex: "#FFB8A1")    // Highlight color – subtle gradients or hover effects
    static let textPrimary = Color(hex: "#1C1C1E")  // Text primary – headings and core text elements
    static let textSecondary = Color(hex: "#4A4A4A")// Text secondary – captions, helper text, and secondary labels
    
    // MARK: - Legacy semantic mappings (for compatibility with existing code)
    static let success = secondary                   // Map to warm orange for success states
    static let info = primary                        // Map to purple for info states
    static let surface1 = surface                    // Map to white surface
    static let surface2 = background                 // Map to pink background
    static let surface3 = Color(hex: "#FFD6E0")      // Lighter pink for variation
    
    // MARK: - Utility Colors
    static let successDark = Color(red: 0.35, green: 0.55, blue: 0.10) // #5A8A1A - darker green for text
    static let errorColor = Color.red // System red for errors
    static let warningColor = Color.orange // System orange for warnings
    static let buttonSurface = Color(white: 0.92) // Light gray surface for navigation buttons
    
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

