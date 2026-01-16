import Foundation

// MARK: - Trade Request
/// Request model for executing a basket trade
struct TradeExecuteRequest: Codable {
    let basket: BasketTradePayload
    let agentWalletAddress: String
    let slippage: Double?
    let reduceOnly: Bool
    
    init(
        basket: Basket,
        agentWalletAddress: String,
        slippage: Double? = 0.5,
        reduceOnly: Bool = false
    ) {
        self.basket = BasketTradePayload(from: basket)
        self.agentWalletAddress = agentWalletAddress
        self.slippage = slippage
        self.reduceOnly = reduceOnly
    }
}

// MARK: - Basket Trade Payload
struct BasketTradePayload: Codable {
    let name: String
    let legs: [LegPayload]
    let totalSize: Double
    let takeProfitPercent: Double?
    let stopLossPercent: Double?
    
    init(from basket: Basket) {
        self.name = basket.displayName
        self.legs = basket.legs.map { LegPayload(from: $0) }
        self.totalSize = basket.totalSize
        self.takeProfitPercent = basket.takeProfitPercent
        self.stopLossPercent = basket.stopLossPercent
    }
    
    struct LegPayload: Codable {
        let assetId: String
        let direction: String
        let weight: Double
        
        init(from leg: BasketLeg) {
            self.assetId = leg.asset.id
            self.direction = leg.direction.rawValue
            self.weight = leg.weight
        }
    }
}

// MARK: - Trade Response
struct TradeExecuteResponse: Codable {
    let orderId: String
    let positionId: String
    let status: TradeStatus
    let executedLegs: [ExecutedLeg]?
    let totalFees: Double
    let timestamp: Date
    let message: String?
}

// MARK: - Executed Leg
struct ExecutedLeg: Codable {
    let assetId: String
    let direction: String
    let executedPrice: Double
    let executedSize: Double
    let fee: Double
}

// MARK: - Trade Status
enum TradeStatus: String, Codable {
    case pending = "PENDING"
    case partial = "PARTIAL"
    case filled = "FILLED"
    case cancelled = "CANCELLED"
    case rejected = "REJECTED"
    case failed = "FAILED"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var isSuccess: Bool {
        self == .filled || self == .partial
    }
    
    var isFinal: Bool {
        self != .pending
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .partial: return "circle.lefthalf.filled"
        case .filled: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .rejected: return "exclamationmark.triangle.fill"
        case .failed: return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Close Position Request
struct ClosePositionRequest: Codable {
    let positionId: String
    let agentWalletAddress: String
    let percentage: Double // 0-100, default 100 for full close
    
    init(positionId: String, agentWalletAddress: String, percentage: Double = 100) {
        self.positionId = positionId
        self.agentWalletAddress = agentWalletAddress
        self.percentage = percentage
    }
}

// MARK: - Close Position Response
struct ClosePositionResponse: Codable {
    let orderId: String
    let positionId: String
    let status: TradeStatus
    let realizedPnL: Double
    let fees: Double
    let timestamp: Date
    let message: String?
}

// MARK: - Trade History Item
struct TradeHistoryItem: Identifiable, Codable {
    let id: String
    let basketName: String
    let entryValue: Double
    let exitValue: Double
    let realizedPnL: Double
    let realizedPnLPercent: Double
    let fees: Double
    let openedAt: Date
    let closedAt: Date
    let legs: [HistoryLeg]
    
    var duration: TimeInterval {
        closedAt.timeIntervalSince(openedAt)
    }
    
    var formattedDuration: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var isProfitable: Bool {
        realizedPnL > 0
    }
}

// MARK: - History Leg
struct HistoryLeg: Codable {
    let assetId: String
    let assetTicker: String
    let direction: TradeDirection
    let entryPrice: Double
    let exitPrice: Double
    let size: Double
    let pnl: Double
}

// MARK: - Trade History Response
struct TradeHistoryResponse: Codable {
    let trades: [TradeHistoryItem]
    let totalRealizedPnL: Double
    let totalFees: Double
    let totalTrades: Int
    let winRate: Double
}

// MARK: - Sample Data
extension TradeHistoryItem {
    static let sample = TradeHistoryItem(
        id: "trade_001",
        basketName: "BTC/ETH Pair",
        entryValue: 1000,
        exitValue: 1150,
        realizedPnL: 145,
        realizedPnLPercent: 14.5,
        fees: 5,
        openedAt: Date().addingTimeInterval(-86400 * 3),
        closedAt: Date().addingTimeInterval(-86400 * 2),
        legs: [
            HistoryLeg(
                assetId: "BTC",
                assetTicker: "BTC",
                direction: .long,
                entryPrice: 42000,
                exitPrice: 44500,
                size: 500,
                pnl: 85
            ),
            HistoryLeg(
                assetId: "ETH",
                assetTicker: "ETH",
                direction: .short,
                entryPrice: 2400,
                exitPrice: 2280,
                size: 500,
                pnl: 60
            )
        ]
    )
}
