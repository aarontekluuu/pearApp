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

// MARK: - Sample Data
extension Asset {
    static let sample = Asset(
        id: "BTC",
        ticker: "BTC",
        name: "Bitcoin",
        price: 43250.50,
        priceChange24h: 1250.25,
        priceChangePercent24h: 2.98,
        volume24h: 15_500_000_000,
        openInterest: 8_200_000_000,
        maxLeverage: 50,
        minOrderSize: 0.001,
        tickSize: 0.1
    )
    
    static let sampleAssets: [Asset] = [
        Asset(
            id: "BTC",
            ticker: "BTC",
            name: "Bitcoin",
            price: 43250.50,
            priceChange24h: 1250.25,
            priceChangePercent24h: 2.98,
            volume24h: 15_500_000_000,
            openInterest: 8_200_000_000,
            maxLeverage: 50,
            minOrderSize: 0.001,
            tickSize: 0.1
        ),
        Asset(
            id: "ETH",
            ticker: "ETH",
            name: "Ethereum",
            price: 2285.75,
            priceChange24h: -45.30,
            priceChangePercent24h: -1.94,
            volume24h: 8_200_000_000,
            openInterest: 4_500_000_000,
            maxLeverage: 50,
            minOrderSize: 0.01,
            tickSize: 0.01
        ),
        Asset(
            id: "SOL",
            ticker: "SOL",
            name: "Solana",
            price: 98.45,
            priceChange24h: 5.20,
            priceChangePercent24h: 5.58,
            volume24h: 2_100_000_000,
            openInterest: 890_000_000,
            maxLeverage: 20,
            minOrderSize: 0.1,
            tickSize: 0.001
        ),
        Asset(
            id: "NVDA",
            ticker: "NVDA",
            name: "NVIDIA",
            price: 485.20,
            priceChange24h: 12.50,
            priceChangePercent24h: 2.64,
            volume24h: 450_000_000,
            openInterest: 120_000_000,
            maxLeverage: 5,
            minOrderSize: 0.01,
            tickSize: 0.01
        ),
        Asset(
            id: "TSLA",
            ticker: "TSLA",
            name: "Tesla",
            price: 248.90,
            priceChange24h: -8.30,
            priceChangePercent24h: -3.23,
            volume24h: 380_000_000,
            openInterest: 95_000_000,
            maxLeverage: 5,
            minOrderSize: 0.01,
            tickSize: 0.01
        )
    ]
}

// MARK: - API Response Models
struct ActiveAssetsResponse: Codable {
    let assets: [Asset]
    let timestamp: Date?
}
