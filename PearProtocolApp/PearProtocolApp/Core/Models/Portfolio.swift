import Foundation

// MARK: - Portfolio Model
/// Aggregated portfolio data across all positions and assets
struct Portfolio: Codable {
    let totalValue: Double
    let totalPnL: Double
    let totalPnLPercent: Double
    let totalMarginUsed: Double
    let availableMargin: Double
    let openPositionsCount: Int
    let closedPositionsCount: Int
    let totalTrades: Int
    let winRate: Double
    let totalFees: Double
    let totalRealizedPnL: Double
    let totalUnrealizedPnL: Double
    let exposure: PortfolioExposure
    let topPositions: [PortfolioPosition]
    let timestamp: Date
    
    var formattedTotalValue: String {
        totalValue.asCurrency
    }
    
    var formattedTotalPnL: String {
        totalPnL.asCurrencyWithSign
    }
    
    var formattedTotalPnLPercent: String {
        totalPnLPercent.asPercentageWithSign
    }
    
    var isProfitable: Bool {
        totalPnL > 0
    }
}

// MARK: - Portfolio Exposure
struct PortfolioExposure: Codable {
    let longExposure: Double
    let shortExposure: Double
    let netExposure: Double
    let exposureByAsset: [String: AssetExposure] // Asset ID -> Exposure
    
    var formattedLongExposure: String {
        longExposure.asCurrency
    }
    
    var formattedShortExposure: String {
        shortExposure.asCurrency
    }
    
    var formattedNetExposure: String {
        netExposure.asCurrencyWithSign
    }
}

// MARK: - Asset Exposure
struct AssetExposure: Codable {
    let assetId: String
    let assetTicker: String
    let longSize: Double
    let shortSize: Double
    let netSize: Double
    
    var formattedNetSize: String {
        netSize.asCurrencyWithSign
    }
}

// MARK: - Portfolio Position
struct PortfolioPosition: Codable {
    let positionId: String
    let basketName: String
    let currentValue: Double
    let unrealizedPnL: Double
    let unrealizedPnLPercent: Double
    let marginUsed: Double
    
    var formattedPnL: String {
        unrealizedPnL.asCurrencyWithSign
    }
}

// MARK: - Portfolio Response
struct PortfolioResponse: Codable {
    let portfolio: Portfolio
    let message: String?
}
