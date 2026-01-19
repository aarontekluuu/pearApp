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

// MARK: - API Response Models
struct PositionsResponse: Codable {
    let positions: [Position]
    let totalUnrealizedPnL: Double
    let totalMarginUsed: Double
}

// MARK: - Close All Positions Request
struct CloseAllPositionsRequest: Codable {
    let agentWalletAddress: String
}

// MARK: - Adjust Position Request
struct AdjustPositionRequest: Codable {
    let agentWalletAddress: String
    let sizeChange: Double // Positive to increase, negative to decrease
    let slippage: Double?
    
    init(agentWalletAddress: String, sizeChange: Double, slippage: Double? = 0.5) {
        self.agentWalletAddress = agentWalletAddress
        self.sizeChange = sizeChange
        self.slippage = slippage
    }
}

// MARK: - Adjust Position Advanced Request
struct AdjustPositionAdvancedRequest: Codable {
    let agentWalletAddress: String
    let targetSizes: [String: Double] // Asset ID -> target absolute size
    let slippage: Double?
    
    init(agentWalletAddress: String, targetSizes: [String: Double], slippage: Double? = 0.5) {
        self.agentWalletAddress = agentWalletAddress
        self.targetSizes = targetSizes
        self.slippage = slippage
    }
}

// MARK: - Adjust Leverage Request
struct AdjustLeverageRequest: Codable {
    let agentWalletAddress: String
    let leverage: Double
    
    init(agentWalletAddress: String, leverage: Double) {
        self.agentWalletAddress = agentWalletAddress
        self.leverage = leverage
    }
}

// MARK: - Update Risk Parameters Request
struct UpdateRiskParametersRequest: Codable {
    let agentWalletAddress: String
    let takeProfitPercent: Double?
    let stopLossPercent: Double?
    
    init(agentWalletAddress: String, takeProfitPercent: Double? = nil, stopLossPercent: Double? = nil) {
        self.agentWalletAddress = agentWalletAddress
        self.takeProfitPercent = takeProfitPercent
        self.stopLossPercent = stopLossPercent
    }
}

// MARK: - Position Adjust Response
struct PositionAdjustResponse: Codable {
    let success: Bool
    let positionId: String
    let updatedPosition: Position?
    let message: String?
    let timestamp: Date
}
