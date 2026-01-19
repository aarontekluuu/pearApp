import Foundation

// MARK: - Market Data Response
/// Comprehensive market data including funding rates, pricing, favorites, etc.
struct MarketDataResponse: Codable {
    let markets: [MarketInfo]
    let fundingRates: [FundingRate]
    let dailyMetrics: DailyMarketMetrics
    let favorites: [String] // Asset IDs
    let timestamp: Date
}

// MARK: - Market Info
struct MarketInfo: Codable {
    let assetId: String
    let ticker: String
    let name: String
    let price: Double
    let priceChange24h: Double
    let priceChangePercent24h: Double
    let volume24h: Double
    let openInterest: Double
    let maxLeverage: Double
    let fundingRate: Double
    let nextFundingTime: Date?
    let isFavorite: Bool
    
    var formattedPrice: String {
        price.asPrice
    }
    
    var formattedChange: String {
        priceChangePercent24h.asPercentageWithSign
    }
    
    var formattedFundingRate: String {
        fundingRate.asPercentage
    }
}

// MARK: - Funding Rate
struct FundingRate: Codable {
    let assetId: String
    let ticker: String
    let rate: Double
    let nextFundingTime: Date
    let predictedRate: Double?
    
    var formattedRate: String {
        rate.asPercentage
    }
}

// MARK: - Daily Market Metrics
struct DailyMarketMetrics: Codable {
    let totalVolume: Double
    let totalOpenInterest: Double
    let activeMarkets: Int
    let averageFundingRate: Double
    let topGainers: [MarketGainerLoser]
    let topLosers: [MarketGainerLoser]
    let date: Date
    
    var formattedTotalVolume: String {
        totalVolume.asCompactNumber
    }
    
    var formattedAverageFundingRate: String {
        averageFundingRate.asPercentage
    }
}

// MARK: - Market Gainer/Loser
struct MarketGainerLoser: Codable {
    let assetId: String
    let ticker: String
    let priceChangePercent: Double
    let volume24h: Double
    
    var formattedChange: String {
        priceChangePercent.asPercentageWithSign
    }
}
