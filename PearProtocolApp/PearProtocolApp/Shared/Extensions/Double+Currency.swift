import Foundation

// MARK: - Currency Formatting
extension Double {
    /// Formats the double as USD currency (e.g., "$1,234.56")
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
    
    /// Formats the double as currency with sign (e.g., "+$1,234.56" or "-$1,234.56")
    var asCurrencyWithSign: String {
        let formatted = abs(self).asCurrency
        if self > 0 {
            return "+\(formatted)"
        } else if self < 0 {
            return "-\(formatted)"
        } else {
            return formatted
        }
    }
    
    /// Formats the double as percentage (e.g., "12.34%")
    var asPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.multiplier = 1
        return formatter.string(from: NSNumber(value: self)) ?? "0.00%"
    }
    
    /// Formats the double as percentage with sign (e.g., "+12.34%" or "-12.34%")
    var asPercentageWithSign: String {
        let sign = self > 0 ? "+" : ""
        return "\(sign)\(asPercentage)"
    }
    
    /// Formats the double as a compact number (e.g., "1.2K", "3.4M")
    var asCompactNumber: String {
        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""
        
        switch absValue {
        case 1_000_000_000...:
            return "\(sign)\(String(format: "%.1fB", absValue / 1_000_000_000))"
        case 1_000_000...:
            return "\(sign)\(String(format: "%.1fM", absValue / 1_000_000))"
        case 1_000...:
            return "\(sign)\(String(format: "%.1fK", absValue / 1_000))"
        default:
            return "\(sign)\(String(format: "%.2f", absValue))"
        }
    }
    
    /// Formats the double as a price with appropriate decimal places
    var asPrice: String {
        let absValue = abs(self)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        
        if absValue >= 1000 {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
        } else if absValue >= 1 {
            formatter.maximumFractionDigits = 4
            formatter.minimumFractionDigits = 2
        } else {
            formatter.maximumFractionDigits = 6
            formatter.minimumFractionDigits = 4
        }
        
        return "$\(formatter.string(from: NSNumber(value: self)) ?? "0.00")"
    }
}

// MARK: - Weight Formatting
extension Double {
    /// Formats the double as a weight percentage for baskets (e.g., "25%")
    var asWeight: String {
        String(format: "%.0f%%", self)
    }
}
