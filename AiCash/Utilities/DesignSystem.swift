import SwiftUI

// MARK: - Design System
// Shared design system for AiCash app

struct DesignSystem {
    // Bold, distinctive palette - warm amber/gold accent with deep charcoal
    static let primary = Color(red: 0.98, green: 0.76, blue: 0.21)  // Rich gold
    static let primaryDark = Color(red: 0.85, green: 0.62, blue: 0.12)
    static let background = Color(red: 0.06, green: 0.06, blue: 0.08)  // Deep charcoal
    static let backgroundElevated = Color(red: 0.09, green: 0.09, blue: 0.12)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let surfaceHover = Color(red: 0.16, green: 0.16, blue: 0.19)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.75)
    static let textMuted = Color(red: 0.5, green: 0.5, blue: 0.55)
    static let accent = Color(red: 0.98, green: 0.76, blue: 0.21)  // Gold accent
    static let success = Color(red: 0.18, green: 0.85, blue: 0.57)
    static let warning = Color(red: 0.98, green: 0.65, blue: 0.23)
    static let error = Color(red: 0.96, green: 0.32, blue: 0.32)

    // Dramatic typography
    static func displayFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // Custom shadows
    static let cardShadow = Color.black.opacity(0.3)
    static let glowShadow = Color.accentColor.opacity(0.25)
}
