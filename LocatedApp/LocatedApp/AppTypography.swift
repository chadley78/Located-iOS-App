import SwiftUI

// MARK: - App Typography System
// Centralized typography - easily switch between system and custom fonts

struct AppTypography {
    // MARK: - Font Configuration
    // Set to nil for system fonts, or specify custom font family name
    static let customFontFamily: String? = "RadioCanadaBig"  // Custom font
    
    // MARK: - Heading Large (Title)
    struct HeadingLarge: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(AppTypography.font(size: 28, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    // MARK: - Heading Medium (Headline)
    struct HeadingMedium: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(AppTypography.font(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    // MARK: - Body Text
    struct Body: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(AppTypography.font(size: 16, weight: .regular))
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    // MARK: - Caption Text
    struct Caption: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(AppTypography.font(size: 14, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Button Text
    struct Button: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(AppTypography.font(size: 18, weight: .semibold))
        }
    }
    
    // MARK: - Font Helper (System or Custom)
    private static func font(size: CGFloat, weight: Font.Weight) -> Font {
        if let fontFamily = customFontFamily {
            // Use custom font
            let fontName: String
            switch weight {
            case .regular:
                fontName = "\(fontFamily)-Regular"
            case .medium:
                fontName = "\(fontFamily)-Medium"
            case .semibold:
                fontName = "\(fontFamily)-SemiBold"
            case .bold:
                fontName = "\(fontFamily)-Bold"
            default:
                fontName = "\(fontFamily)-Regular"
            }
            return Font.custom(fontName, size: size)
        } else {
            // Use system font
            return Font.system(size: size, weight: weight, design: .default)
        }
    }
}

// MARK: - Convenience Extensions
extension View {
    func headingLarge() -> some View {
        self.modifier(AppTypography.HeadingLarge())
    }
    
    func headingMedium() -> some View {
        self.modifier(AppTypography.HeadingMedium())
    }
    
    func bodyText() -> some View {
        self.modifier(AppTypography.Body())
    }
    
    func captionText() -> some View {
        self.modifier(AppTypography.Caption())
    }
    
    func buttonText() -> some View {
        self.modifier(AppTypography.Button())
    }
}

