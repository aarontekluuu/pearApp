import Foundation

// MARK: - Account Model
/// Represents user account summary with margin info and agent wallet status
struct Account: Codable {
    let userId: String
    let agentWalletAddress: String?
    let agentWalletStatus: AgentWalletStatus?
    let marginInfo: MarginInfo
    let totalPortfolioValue: Double
    let totalUnrealizedPnL: Double
    let totalMarginUsed: Double
    let availableMargin: Double
    let leverage: Double
    let timestamp: Date
}

// MARK: - Agent Wallet Status
enum AgentWalletStatus: String, Codable {
    case active = "ACTIVE"
    case expired = "EXPIRED"
    case notFound = "NOT_FOUND"
    case pending = "PENDING"
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Margin Info
struct MarginInfo: Codable {
    let totalMargin: Double
    let usedMargin: Double
    let availableMargin: Double
    let marginRatio: Double // used / total
    let maintenanceMargin: Double
    let initialMargin: Double
    
    var formattedTotalMargin: String {
        totalMargin.asCurrency
    }
    
    var formattedUsedMargin: String {
        usedMargin.asCurrency
    }
    
    var formattedAvailableMargin: String {
        availableMargin.asCurrency
    }
    
    var marginUsagePercent: Double {
        guard totalMargin > 0 else { return 0 }
        return (usedMargin / totalMargin) * 100
    }
}

// MARK: - Account Response
struct AccountResponse: Codable {
    let account: Account
    let message: String?
}
