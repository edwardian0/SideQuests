import SwiftUICore
import UIKit

extension Font {
    
    static func header() -> Font{
        return poppins(size: .title2, weight: .bold)
    }
    
    static func normalText() -> Font{
        return satoshi(weight: .light)
    }
    
    static func satoshi(size: CustomFontSize = .body, weight: CustomFontWeight = .regular, italic: Bool = false) -> Font {
        return font(name: "Satoshi", size: size, weight: weight, italic: italic)
    }
    
    static func poppins(size: CustomFontSize = .body, weight: CustomFontWeight = .regular, italic: Bool = false) -> Font {
        return font(name: "Poppins", size: size, weight: weight, italic: italic)
    }
    
    private static func font(name: String, size: CustomFontSize, weight: CustomFontWeight, italic: Bool) -> Font {
        let sizeCategory = UIApplication.shared.preferredContentSizeCategory
        
        let italicSuffix = italic ? "Italic" : ""
        let fontName = "\(name)-\(weight)\(italicSuffix)"
        
        let adjustedSize = size.rawValue * sizeCategoryToValue(sizeCategory)
        return .custom(fontName, size: adjustedSize)
    }
    
    private static func sizeCategoryToValue(_ category :UIContentSizeCategory) -> CGFloat {
        switch category {
            case .extraSmall: return 0.82
            case .small: return 0.88
            case .medium: return 0.95
            case .large: return 1.0 // Base
            case .extraLarge: return 1.12
            case .extraExtraLarge: return 1.23
            case .extraExtraExtraLarge: return 1.35
            case .accessibilityMedium: return 1.64
            case .accessibilityLarge: return 1.95
            case .accessibilityExtraLarge: return 2.35
            case .accessibilityExtraExtraLarge: return 2.76
            case .accessibilityExtraExtraExtraLarge: return 3.12
            default: return 1.0
        }
    }
}

enum CustomFontWeight: String {
    case black = "Black"
    case bold = "Bold"
    case light = "Light"
    case medium = "Medium"
    case regular = "Regular"
}

enum CustomFontSize: CGFloat {
    case largeTitle = 34.0
    case title = 28.0
    case title2 = 22.0
    case title3 = 20.0
    case headline = 18.0
    case subheadline = 15.0
    case body = 17.0
    case callout = 16.0
    case footnote = 13.0
    case caption = 12.0
    case caption2 = 11.0
}
