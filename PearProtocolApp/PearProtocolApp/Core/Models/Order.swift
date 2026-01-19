import Foundation

// MARK: - Order Model
/// Represents a trading order (non-pair trading operations)
struct Order: Identifiable, Codable {
    let id: String
    let assetId: String
    let assetTicker: String
    let direction: TradeDirection
    let orderType: OrderType
    let status: OrderStatus
    let size: Double
    let price: Double?
    let filledSize: Double
    let averageFillPrice: Double?
    let createdAt: Date
    let updatedAt: Date?
    let expiresAt: Date?
    let fees: Double
    
    var remainingSize: Double {
        size - filledSize
    }
    
    var fillPercentage: Double {
        guard size > 0 else { return 0 }
        return (filledSize / size) * 100
    }
    
    var formattedSize: String {
        size.asCurrency
    }
    
    var formattedFilledSize: String {
        filledSize.asCurrency
    }
    
    var formattedPrice: String? {
        price?.asPrice
    }
    
    var isFilled: Bool {
        status == .filled
    }
    
    var isPending: Bool {
        status == .pending
    }
}

// MARK: - Order Type
enum OrderType: String, Codable {
    case market = "MARKET"
    case limit = "LIMIT"
    case stop = "STOP"
    case stopLimit = "STOP_LIMIT"
    case takeProfit = "TAKE_PROFIT"
    case stopLoss = "STOP_LOSS"
    
    var displayName: String {
        switch self {
        case .market: return "Market"
        case .limit: return "Limit"
        case .stop: return "Stop"
        case .stopLimit: return "Stop Limit"
        case .takeProfit: return "Take Profit"
        case .stopLoss: return "Stop Loss"
        }
    }
}

// MARK: - Order Status
enum OrderStatus: String, Codable {
    case pending = "PENDING"
    case partial = "PARTIAL"
    case filled = "FILLED"
    case cancelled = "CANCELLED"
    case rejected = "REJECTED"
    case expired = "EXPIRED"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .partial: return "circle.lefthalf.filled"
        case .filled: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .rejected: return "exclamationmark.triangle.fill"
        case .expired: return "clock.badge.xmark"
        }
    }
}

// MARK: - TWAP Order
struct TWAPOrder: Codable {
    let orderId: String
    let status: TWAPStatus
    let totalSize: Double
    let filledSize: Double
    let remainingSize: Double
    let duration: TimeInterval // Total duration in seconds
    let elapsedTime: TimeInterval // Time elapsed in seconds
    let interval: TimeInterval // Interval between fills in seconds
    let nextFillAt: Date?
    let averageFillPrice: Double?
    let createdAt: Date
    let updatedAt: Date?
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1.0, elapsedTime / duration)
    }
    
    var fillPercentage: Double {
        guard totalSize > 0 else { return 0 }
        return (filledSize / totalSize) * 100
    }
    
    var formattedProgress: String {
        "\(Int(fillPercentage))%"
    }
}

// MARK: - TWAP Status
enum TWAPStatus: String, Codable {
    case pending = "PENDING"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case failed = "FAILED"
    
    var displayName: String {
        rawValue.capitalized.replacingOccurrences(of: "_", with: " ")
    }
}

// MARK: - Open Orders Response
struct OpenOrdersResponse: Codable {
    let orders: [Order]
    let totalCount: Int
}

// MARK: - TWAP Orders Response
struct TWAPOrdersResponse: Codable {
    let twapOrders: [TWAPOrder]
    let totalCount: Int
}

// MARK: - Spot Order Request
struct SpotOrderRequest: Codable {
    let assetId: String
    let direction: String // "LONG" or "SHORT"
    let size: Double
    let orderType: String // "MARKET" or "LIMIT"
    let price: Double? // Required for LIMIT orders
    let agentWalletAddress: String
    let slippage: Double?
    
    init(
        assetId: String,
        direction: TradeDirection,
        size: Double,
        orderType: OrderType,
        price: Double? = nil,
        agentWalletAddress: String,
        slippage: Double? = 0.5
    ) {
        self.assetId = assetId
        self.direction = direction.rawValue
        self.size = size
        self.orderType = orderType.rawValue
        self.price = price
        self.agentWalletAddress = agentWalletAddress
        self.slippage = slippage
    }
}

// MARK: - Spot Order Response
struct SpotOrderResponse: Codable {
    let orderId: String
    let status: OrderStatus
    let filledSize: Double?
    let averageFillPrice: Double?
    let fees: Double
    let timestamp: Date
    let message: String?
}

// MARK: - Cancel Order Response
struct CancelOrderResponse: Codable {
    let success: Bool
    let orderId: String
    let message: String?
}
