import SwiftUI

// MARK: - Radio Canada Big Static Font Extension
extension Font {
    static func radioCanadaBig(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName: String
        
        switch weight {
        case .regular:
            fontName = "RadioCanadaBig-Regular"
        case .medium:
            fontName = "RadioCanadaBig-Medium"
        case .semibold:
            fontName = "RadioCanadaBig-SemiBold"
        case .bold:
            fontName = "RadioCanadaBig-Bold"
        default:
            fontName = "RadioCanadaBig-Regular"
        }
        
        return Font.custom(fontName, size: size)
    }
    
    // Convenience methods for common sizes
    static let radioCanadaBigTitle = Font.radioCanadaBig(28, weight: .bold)
    static let radioCanadaBigHeadline = Font.radioCanadaBig(20, weight: .semibold)
    static let radioCanadaBigBody = Font.radioCanadaBig(16, weight: .regular)
    static let radioCanadaBigCaption = Font.radioCanadaBig(14, weight: .regular)
    static let radioCanadaBigButton = Font.radioCanadaBig(18, weight: .semibold)
}
