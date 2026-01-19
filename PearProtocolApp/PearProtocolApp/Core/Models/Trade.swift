import Foundation

// MARK: - Trade Request
/// Request model for executing a basket trade (POST /positions)
/// Matches CreatePositionRequestDto from Pear Protocol API
struct TradeExecuteRequest: Codable {
    let slippage: Double  // Required: 0.001-0.1 (where 0.01 = 1%)
    let executionType: String  // Required: "SYNC" | "MARKET" | "TRIGGER" | "TWAP" | "LADDER" | etc.
    let leverage: Double  // Required: 1-100
    let usdValue: Double  // Required: minimum 1
    let longAssets: [PairAssetDto]?  // Optional: array of {asset: string, weight?: number}
    let shortAssets: [PairAssetDto]?  // Optional: array of {asset: string, weight?: number}
    let stopLoss: TpSlThreshold?  // Optional: TpSlThreshold object
    let takeProfit: TpSlThreshold?  // Optional: TpSlThreshold object
    
    init(
        basket: Basket,
        slippage: Double = 0.005,  // Default 0.5% (0.005)
        executionType: String = "MARKET",
        leverage: Double = 1.0
    ) {
        // Required fields
        self.slippage = slippage
        self.executionType = executionType
        self.leverage = leverage
        self.usdValue = basket.totalSize
        
        // Convert basket legs to longAssets/shortAssets arrays
        var longAssetsArray: [PairAssetDto] = []
        var shortAssetsArray: [PairAssetDto] = []
        
        for leg in basket.legs {
            // Convert weight from percentage (0-100) to decimal (0.0001-1.0)
            let weightDecimal = max(0.0001, min(1.0, leg.weight / 100.0))
            
            let pairAsset = PairAssetDto(
                asset: leg.asset.ticker,  // Use ticker (symbol) not id
                weight: weightDecimal
            )
            
            if leg.direction == .long {
                longAssetsArray.append(pairAsset)
            } else {
                shortAssetsArray.append(pairAsset)
            }
        }
        
        self.longAssets = longAssetsArray.isEmpty ? nil : longAssetsArray
        self.shortAssets = shortAssetsArray.isEmpty ? nil : shortAssetsArray
        
        // Convert TP/SL from percentages to TpSlThreshold objects
        if let tpPercent = basket.takeProfitPercent {
            self.takeProfit = TpSlThreshold(
                type: "PERCENTAGE",
                value: tpPercent,
                isTrailing: false,
                trailingDeltaValue: nil,
                trailingActivationValue: nil
            )
        } else {
            self.takeProfit = nil
        }
        
        if let slPercent = basket.stopLossPercent {
            self.stopLoss = TpSlThreshold(
                type: "PERCENTAGE",
                value: slPercent,
                isTrailing: false,
                trailingDeltaValue: nil,
                trailingActivationValue: nil
            )
        } else {
            self.stopLoss = nil
        }
    }
}

// MARK: - TP/SL Threshold
/// Stop loss or take profit threshold configuration
struct TpSlThreshold: Codable {
    let type: String  // "PERCENTAGE" | "DOLLAR" | "POSITION_VALUE" | "PRICE" | "PRICE_RATIO" | "WEIGHTED_RATIO"
    let value: Double
    let isTrailing: Bool?
    let trailingDeltaValue: Double?
    let trailingActivationValue: Double?
}

// MARK: - Trade Response
/// Response from POST /positions (CreatePositionResponseDto)
struct TradeExecuteResponse: Codable {
    let orderId: String
    let fills: [Fill]?
    
    // Computed properties for backward compatibility
    var positionId: String {
        orderId  // Use orderId as positionId for now
    }
    
    var status: TradeStatus {
        .pending  // Default status - will be updated from position status
    }
    
    var executedLegs: [ExecutedLeg]? {
        fills?.map { fill in
            ExecutedLeg(
                assetId: fill.coin ?? "",
                direction: fill.side ?? "LONG",
                executedPrice: fill.px ?? 0,
                executedSize: fill.sz ?? 0,
                fee: 0  // Fee not in fill object
            )
        }
    }
    
    var totalFees: Double {
        0  // Calculate from fills if needed
    }
    
    var timestamp: Date {
        Date()
    }
    
    var message: String? {
        nil
    }
}

// MARK: - Fill
/// Fill information from Hyperliquid
struct Fill: Codable {
    let coin: String?
    let px: Double?  // Price
    let sz: Double?  // Size
    let side: String?  // "A" (ask/long) or "B" (bid/short)
    let time: Int64?
    let startPosition: String?
    let dir: String?
    let closedPnl: String?
    let hash: String?
    let oid: Int64?
    let crossed: Bool?
    let closedSize: String?
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
