import Foundation

// MARK: - Position Model
/// Represents an open or closed basket position
struct Position: Identifiable, Codable {
    let id: String
    let basketId: String
    var basketName: String
    var legs: [PositionLeg]
    var entryValue: Double
    var currentValue: Double
    var unrealizedPnL: Double
    var unrealizedPnLPercent: Double
    var realizedPnL: Double
    var marginUsed: Double
    var leverage: Double
    var takeProfitPercent: Double?
    var stopLossPercent: Double?
    var fundingFees: Double
    var status: PositionStatus
    var openedAt: Date
    var closedAt: Date?
    
    // MARK: - Computed Properties
    var totalPnL: Double {
        unrealizedPnL + realizedPnL - fundingFees
    }
    
    var totalPnLPercent: Double {
        guard entryValue > 0 else { return 0 }
        return (totalPnL / entryValue) * 100
    }
    
    var isProfitable: Bool {
        totalPnL > 0
    }
    
    var formattedPnL: String {
        totalPnL.asCurrencyWithSign
    }
    
    var formattedPnLPercent: String {
        totalPnLPercent.asPercentageWithSign
    }
    
    var formattedEntryValue: String {
        entryValue.asCurrency
    }
    
    var formattedCurrentValue: String {
        currentValue.asCurrency
    }
    
    var timeOpen: String {
        let interval = Date().timeIntervalSince(openedAt)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var isOpen: Bool {
        status == .open
    }
    
    // MARK: - TP/SL Status
    var takeProfitPrice: Double? {
        guard let tp = takeProfitPercent else { return nil }
        return entryValue * (1 + tp / 100)
    }
    
    var stopLossPrice: Double? {
        guard let sl = stopLossPercent else { return nil }
        return entryValue * (1 - sl / 100)
    }
}

// MARK: - Position Leg
/// Represents a single leg within a position
struct PositionLeg: Identifiable, Codable {
    let id: String
    let assetId: String
    let assetTicker: String
    let direction: TradeDirection
    var size: Double // Notional size in USDC
    var entryPrice: Double
    var currentPrice: Double
    var unrealizedPnL: Double
    var unrealizedPnLPercent: Double
    var weight: Double
    
    // MARK: - Computed Properties
    var isProfitable: Bool {
        unrealizedPnL > 0
    }
    
    var formattedPnL: String {
        unrealizedPnL.asCurrencyWithSign
    }
    
    var formattedPnLPercent: String {
        unrealizedPnLPercent.asPercentageWithSign
    }
    
    var formattedEntryPrice: String {
        entryPrice.asPrice
    }
    
    var formattedCurrentPrice: String {
        currentPrice.asPrice
    }
    
    var formattedSize: String {
        size.asCurrency
    }
}

// MARK: - Position Status
enum PositionStatus: String, Codable {
    case open = "OPEN"
    case closed = "CLOSED"
    case liquidated = "LIQUIDATED"
    case pending = "PENDING"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .open: return "circle.fill"
        case .closed: return "checkmark.circle.fill"
        case .liquidated: return "exclamationmark.triangle.fill"
        case .pending: return "clock.fill"
        }
    }
}

// MARK: - Sample Data
extension Position {
    static let sample = Position(
        id: "pos_001",
        basketId: "basket_001",
        basketName: "BTC/ETH Pair",
        legs: [
            PositionLeg(
                id: "leg_001",
                assetId: "BTC",
                assetTicker: "BTC",
                direction: .long,
                size: 500,
                entryPrice: 43000,
                currentPrice: 43250,
                unrealizedPnL: 12.50,
                unrealizedPnLPercent: 2.5,
                weight: 50
            ),
            PositionLeg(
                id: "leg_002",
                assetId: "ETH",
                assetTicker: "ETH",
                direction: .short,
                size: 500,
                entryPrice: 2300,
                currentPrice: 2285,
                unrealizedPnL: 7.50,
                unrealizedPnLPercent: 1.5,
                weight: 50
            )
        ],
        entryValue: 1000,
        currentValue: 1020,
        unrealizedPnL: 20,
        unrealizedPnLPercent: 2.0,
        realizedPnL: 0,
        marginUsed: 100,
        leverage: 10,
        takeProfitPercent: 10,
        stopLossPercent: 5,
        fundingFees: 0.50,
        status: .open,
        openedAt: Date().addingTimeInterval(-3600 * 4) // 4 hours ago
    )
    
    static let samplePositions: [Position] = [
        sample,
        Position(
            id: "pos_002",
            basketId: "basket_002",
            basketName: "SOL Long",
            legs: [
                PositionLeg(
                    id: "leg_003",
                    assetId: "SOL",
                    assetTicker: "SOL",
                    direction: .long,
                    size: 500,
                    entryPrice: 95.00,
                    currentPrice: 98.45,
                    unrealizedPnL: 18.15,
                    unrealizedPnLPercent: 3.63,
                    weight: 100
                )
            ],
            entryValue: 500,
            currentValue: 518.15,
            unrealizedPnL: 18.15,
            unrealizedPnLPercent: 3.63,
            realizedPnL: 0,
            marginUsed: 50,
            leverage: 10,
            takeProfitPercent: nil,
            stopLossPercent: nil,
            fundingFees: 0.25,
            status: .open,
            openedAt: Date().addingTimeInterval(-3600 * 12) // 12 hours ago
        ),
        Position(
            id: "pos_003",
            basketId: "basket_003",
            basketName: "NVDA/TSLA Tech",
            legs: [
                PositionLeg(
                    id: "leg_004",
                    assetId: "NVDA",
                    assetTicker: "NVDA",
                    direction: .long,
                    size: 300,
                    entryPrice: 490,
                    currentPrice: 485.20,
                    unrealizedPnL: -2.94,
                    unrealizedPnLPercent: -0.98,
                    weight: 60
                ),
                PositionLeg(
                    id: "leg_005",
                    assetId: "TSLA",
                    assetTicker: "TSLA",
                    direction: .short,
                    size: 200,
                    entryPrice: 245,
                    currentPrice: 248.90,
                    unrealizedPnL: -3.18,
                    unrealizedPnLPercent: -1.59,
                    weight: 40
                )
            ],
            entryValue: 500,
            currentValue: 493.88,
            unrealizedPnL: -6.12,
            unrealizedPnLPercent: -1.22,
            realizedPnL: 0,
            marginUsed: 100,
            leverage: 5,
            takeProfitPercent: 15,
            stopLossPercent: 8,
            fundingFees: 0.35,
            status: .open,
            openedAt: Date().addingTimeInterval(-3600 * 24) // 24 hours ago
        )
    ]
}

// MARK: - API Response Models
struct PositionsResponse: Codable {
    let positions: [Position]
    let totalUnrealizedPnL: Double
    let totalMarginUsed: Double
}
