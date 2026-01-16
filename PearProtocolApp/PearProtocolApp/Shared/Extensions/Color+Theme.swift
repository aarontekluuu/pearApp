import SwiftUI

// MARK: - Pear Protocol Theme Colors
extension Color {
    // Primary brand color (pear green with golden tint)
    static let pearPrimary = Color("PearPrimary")
    
    // Trading colors
    static let pearProfit = Color("PearProfit")     // #00D395 - Profit/Long
    static let pearLoss = Color("PearLoss")         // #FF4D4D - Loss/Short
    
    // Background colors
    static let backgroundPrimary = Color("BackgroundPrimary")     // #0A0E27 - Main background
    static let backgroundSecondary = Color("BackgroundSecondary") // #1A1E3D - Card background
    
    // Convenience accessors with fallbacks
    static var profit: Color { pearProfit }
    static var loss: Color { pearLoss }
    
    // Gradient for primary actions
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.467, green: 0.341, blue: 0.925),  // Purple
                Color(red: 0.580, green: 0.820, blue: 0.200)   // Pear green
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Background gradient
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.039, green: 0.055, blue: 0.153),
                Color(red: 0.063, green: 0.078, blue: 0.180)
            ],
            startPoint: .top,
            endPoint: .bottom
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
            return .secondary
        }
    }
}

// MARK: - Dynamic Colors for Direction
extension Color {
    static func directionColor(isLong: Bool) -> Color {
        isLong ? .pearProfit : .pearLoss
    }
}
