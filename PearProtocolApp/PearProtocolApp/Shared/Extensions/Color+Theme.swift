import SwiftUI

// MARK: - Pear Protocol Design System
// Official color palette and design tokens

extension Color {
    // MARK: - Primary Actions
    /// Primary action color - buttons, CTAs, highlights
    static let pearPrimary = Color(hex: "A2DB5C")
    
    // MARK: - Backgrounds
    /// Main app background
    static let backgroundPrimary = Color(hex: "080807")
    /// Secondary containers, short position cards
    static let backgroundSecondary = Color(hex: "202919")
    /// Tertiary containers, long position cards
    static let backgroundTertiary = Color(hex: "141C15")
    
    // MARK: - Semantic Colors
    /// Profit/positive values, long positions
    static let pearProfit = Color(hex: "A2DB5C")
    /// Loss/negative values, short positions
    static let pearLoss = Color(hex: "FF6B6B")
    /// Warning/amber accent for short positions
    static let pearWarning = Color(hex: "FFAA5C")
    /// Amber/red accent for short positions
    static let shortPositionAccent = Color(hex: "FFAA5C")
    
    // MARK: - Text Colors with Opacity Hierarchy
    /// Primary text - headlines, important values (100% opacity)
    static let textPrimary = Color.white
    /// Secondary text - labels, descriptions (60% opacity)
    static let textSecondary = Color.white.opacity(0.6)
    /// Tertiary text - hints, timestamps, subtle info (40% opacity)
    static let textTertiary = Color.white.opacity(0.4)
    /// Quaternary text - disabled, placeholders (25% opacity)
    static let textQuaternary = Color.white.opacity(0.25)
    
    // MARK: - Icon Opacity Hierarchy
    /// Primary icons - active, interactive (100% opacity)
    static let iconPrimary = Color.white
    /// Secondary icons - navigation, supporting (60% opacity)
    static let iconSecondary = Color.white.opacity(0.6)
    /// Tertiary icons - decorative, subtle (35% opacity)
    static let iconTertiary = Color.white.opacity(0.35)
    /// Disabled icons (20% opacity)
    static let iconDisabled = Color.white.opacity(0.2)
    
    // MARK: - Surface Opacity Hierarchy
    /// Elevated surface - modals, popovers
    static let surfaceElevated = Color(hex: "2A3422")
    /// Pressed/active state overlay
    static let surfacePressed = Color.white.opacity(0.08)
    /// Hover state overlay
    static let surfaceHover = Color.white.opacity(0.04)
    
    // MARK: - Border Opacity Hierarchy
    /// Strong border - focused inputs, selected items
    static let borderStrong = Color.white.opacity(0.2)
    /// Default border - cards, containers
    static let borderDefault = Color.white.opacity(0.1)
    /// Subtle border - dividers, separators
    static let borderSubtle = Color.white.opacity(0.06)
    
    // MARK: - Dividers & Borders
    /// Divider color at 50% opacity
    static let divider = Color(hex: "080C03").opacity(0.5)
    
    // MARK: - Position-Specific Backgrounds
    /// Long position background
    static let longPositionBg = Color(hex: "141C15")
    /// Short position background
    static let shortPositionBg = Color(hex: "202919")
    
    // MARK: - Gradients
    /// Primary gradient for CTAs
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "A2DB5C"),
                Color(hex: "8BC34A")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Subtle glow gradient for profit
    static var profitGlow: RadialGradient {
        RadialGradient(
            colors: [
                Color(hex: "A2DB5C").opacity(0.3),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
    
    /// Background gradient
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "080807"),
                Color(hex: "0D0F0A")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Top header gradient - fades from pear green to background
    static var topHeaderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.pearPrimary,
                Color.backgroundPrimary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Legacy Aliases (for backward compatibility)
    static var profit: Color { pearProfit }
    static var loss: Color { pearLoss }
}

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - PnL Color Helper
extension Color {
    static func pnlColor(for value: Double) -> Color {
        if value > 0 {
            return .pearProfit
        } else if value < 0 {
            return .pearLoss
        } else {
            return .textSecondary
        }
    }
}

// MARK: - Dynamic Colors for Direction
extension Color {
    static func directionColor(isLong: Bool) -> Color {
        isLong ? .pearProfit : .pearLoss
    }
    
    static func directionBackground(isLong: Bool) -> Color {
        isLong ? .longPositionBg : .shortPositionBg
    }
}
