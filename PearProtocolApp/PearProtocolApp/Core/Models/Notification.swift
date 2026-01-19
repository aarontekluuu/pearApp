import Foundation

// MARK: - Notification Model
/// Represents a user notification
struct PearNotification: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let isRead: Bool
    let createdAt: Date
    let relatedId: String? // positionId, orderId, etc.
    let actionUrl: String?
    let metadata: [String: String]?
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var icon: String {
        type.icon
    }
}

// MARK: - Notification Type
enum NotificationType: String, Codable {
    case positionOpened = "POSITION_OPENED"
    case positionClosed = "POSITION_CLOSED"
    case positionLiquidated = "POSITION_LIQUIDATED"
    case orderFilled = "ORDER_FILLED"
    case orderCancelled = "ORDER_CANCELLED"
    case takeProfitHit = "TAKE_PROFIT_HIT"
    case stopLossHit = "STOP_LOSS_HIT"
    case slippageAlert = "SLIPPAGE_ALERT"
    case marginWarning = "MARGIN_WARNING"
    case system = "SYSTEM"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .positionOpened: return "Position Opened"
        case .positionClosed: return "Position Closed"
        case .positionLiquidated: return "Position Liquidated"
        case .orderFilled: return "Order Filled"
        case .orderCancelled: return "Order Cancelled"
        case .takeProfitHit: return "Take Profit Hit"
        case .stopLossHit: return "Stop Loss Hit"
        case .slippageAlert: return "Slippage Alert"
        case .marginWarning: return "Margin Warning"
        case .system: return "System"
        case .other: return "Notification"
        }
    }
    
    var icon: String {
        switch self {
        case .positionOpened: return "arrow.up.circle.fill"
        case .positionClosed: return "arrow.down.circle.fill"
        case .positionLiquidated: return "exclamationmark.triangle.fill"
        case .orderFilled: return "checkmark.circle.fill"
        case .orderCancelled: return "xmark.circle.fill"
        case .takeProfitHit: return "chart.line.uptrend.xyaxis"
        case .stopLossHit: return "chart.line.downtrend.xyaxis"
        case .slippageAlert: return "exclamationmark.circle.fill"
        case .marginWarning: return "exclamationmark.octagon.fill"
        case .system: return "info.circle.fill"
        case .other: return "bell.fill"
        }
    }
}

// MARK: - Notifications Response
struct NotificationsResponse: Codable {
    let notifications: [PearNotification]
    let totalCount: Int
    let unreadCount: Int
    let hasMore: Bool
}

// MARK: - Mark Notifications Read Request
struct MarkNotificationsReadRequest: Codable {
    let notificationIds: [String]?
    let readUpToTimestamp: Date?
    
    init(notificationIds: [String]? = nil, readUpToTimestamp: Date? = nil) {
        self.notificationIds = notificationIds
        self.readUpToTimestamp = readUpToTimestamp
    }
}

// MARK: - Mark Notifications Read Response
struct MarkNotificationsReadResponse: Codable {
    let success: Bool
    let markedCount: Int
    let message: String?
}
