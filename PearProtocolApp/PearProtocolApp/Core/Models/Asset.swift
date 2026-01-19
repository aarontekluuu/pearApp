import Foundation

// MARK: - Asset Model
/// Represents a tradeable asset on Hyperliquid
struct Asset: Identifiable, Codable, Hashable {
    let id: String
    let ticker: String
    let name: String
    var price: Double
    var priceChange24h: Double
    var priceChangePercent24h: Double
    var volume24h: Double
    var openInterest: Double?
    var maxLeverage: Double
    var minOrderSize: Double
    var tickSize: Double
    
    // MARK: - Computed Properties
    var displayTicker: String {
        ticker.uppercased()
    }
    
    var isPriceUp: Bool {
        priceChange24h >= 0
    }
    
    var formattedPrice: String {
        price.asPrice
    }
    
    var formattedChange: String {
        priceChangePercent24h.asPercentageWithSign
    }
    
    var formattedVolume: String {
        volume24h.asCompactNumber
    }
}

// MARK: - Asset Category
enum AssetCategory: String, CaseIterable, Codable {
    case crypto = "Crypto"
    case stocks = "Stocks"
    case forex = "Forex"
    case commodities = "Commodities"
    
    var icon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle.fill"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .forex: return "dollarsign.circle.fill"
        case .commodities: return "cube.fill"
        }
    }
}

// MARK: - API Response Models
/// Response from GET /markets/active
struct ActiveAssetsResponse: Codable {
    let active: [ActiveAssetGroupItem]
    let topGainers: [ActiveAssetGroupItem]
    let topLosers: [ActiveAssetGroupItem]
    let highlighted: [ActiveAssetGroupItem]
    let watchlist: [ActiveAssetGroupItem]
}

/// Active asset group item containing long/short pairs
struct ActiveAssetGroupItem: Codable {
    let key: String
    let longAssets: [PairAssetDto]
    let shortAssets: [PairAssetDto]
    let openInterest: String
    let volume: String
    let ratio: String?
    let prevRatio: String?
    let change24h: String?
    let weightedRatio: String?
    let weightedPrevRatio: String?
    let weightedChange24h: String?
    let netFunding: String
}

/// Pair asset DTO with asset symbol and weight
struct PairAssetDto: Codable {
    let asset: String  // Asset symbol (e.g., "BTC", "ETH")
    let weight: Double?  // Weight allocation (0.0001 to 1.0)
}
