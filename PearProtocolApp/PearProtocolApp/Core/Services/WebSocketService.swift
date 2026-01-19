import Foundation
import Starscream
import Combine

// MARK: - WebSocket Service
/// Real-time data streaming service for prices, positions, and trade fills
@MainActor
final class WebSocketService: ObservableObject {
    static let shared = WebSocketService()
    
    // MARK: - Published State
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var lastError: String?
    
    // MARK: - Publishers
    let priceUpdates = PassthroughSubject<PriceUpdate, Never>()
    let positionUpdates = PassthroughSubject<PositionUpdate, Never>()
    let fillUpdates = PassthroughSubject<FillUpdate, Never>()
    let openOrderUpdates = PassthroughSubject<OpenOrderUpdate, Never>()
    let tradeHistoryUpdates = PassthroughSubject<TradeHistoryUpdate, Never>()
    let twapDetailsUpdates = PassthroughSubject<TWAPDetailsUpdate, Never>()
    let notificationUpdates = PassthroughSubject<NotificationUpdate, Never>()
    let accountSummaryUpdates = PassthroughSubject<AccountSummaryUpdate, Never>()
    let marketDataUpdates = PassthroughSubject<MarketDataUpdate, Never>()
    
    // MARK: - Private Properties
    private var socket: WebSocket?
    private var reconnectAttempts = 0
    private var maxReconnectAttempts = 5
    private var reconnectDelay: TimeInterval = 1.0
    private var pingTimer: Timer?
    private var subscribedChannels: Set<String> = []
    private var authToken: String?
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
    }
    
    private init() {}

    func setAuthToken(_ token: String?) {
        let hadToken = authToken != nil
        let tokenChanged = authToken != token
        
        if let token, !token.isEmpty {
            authToken = token
            print("🔵 [DEBUG] WebSocket auth token set (length: \(token.count))")
        } else {
            authToken = nil
            print("🔵 [DEBUG] WebSocket auth token cleared")
        }
        
        // If token changed and we're connected, reconnect with new token
        if tokenChanged && isConnected {
            print("🔵 [DEBUG] Auth token changed while connected - reconnecting WebSocket")
            // Preserve subscriptions before disconnecting
            let preservedChannels = subscribedChannels
            disconnect()
            // Restore subscriptions so they'll be resubscribed on reconnect
            subscribedChannels = preservedChannels
            // Small delay before reconnecting to ensure clean disconnect
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                connect()
            }
        } else if tokenChanged && !isConnected && token != nil {
            // Token was set but we're not connected - connect now
            print("🔵 [DEBUG] Auth token set while disconnected - connecting WebSocket")
            connect()
        }
    }
    
    // MARK: - Connection
    func connect() {
        // If already connected, don't reconnect
        guard socket == nil || !isConnected else {
            print("🔵 [DEBUG] WebSocket already connected, skipping connection")
            return
        }
        
        // If socket exists but not connected, disconnect first to allow reconnection
        if let existingSocket = socket, !isConnected {
            print("🔵 [DEBUG] WebSocket exists but not connected, disconnecting first")
            existingSocket.disconnect()
            socket = nil
        }
        
        connectionState = .connecting
        
        var request = URLRequest(url: URL(string: Constants.API.webSocketURL)!)
        request.timeoutInterval = 10
        
        // Add auth token if available
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔵 [DEBUG] WebSocket connecting with auth token")
        } else {
            print("🔵 [DEBUG] WebSocket connecting without auth token (public data only)")
        }
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
        
        print("🔵 [DEBUG] WebSocket connection initiated to: \(Constants.API.webSocketURL)")
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        socket?.disconnect()
        socket = nil
        isConnected = false
        connectionState = .disconnected
        // Don't clear subscribedChannels - we want to resubscribe on reconnect
        // subscribedChannels will be preserved for resubscribeAll()
    }
    
    private func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            lastError = "Maximum reconnection attempts reached"
            connectionState = .disconnected
            return
        }
        
        connectionState = .reconnecting
        reconnectAttempts += 1
        
        let delay = reconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.socket?.connect()
        }
    }
    
    // MARK: - Subscriptions
    func subscribeToPrices(assets: [String]) {
        print("🔵 [DEBUG] Subscribing to prices for \(assets.count) assets: \(assets.joined(separator: ", "))")
        
        // #region agent log
        DebugLogger.log(
            location: "WebSocketService.swift:141",
            message: "Subscribing to price channels",
            data: [
                "assetCount": assets.count,
                "assetIds": assets,
                "assetIdsLowercase": assets.map { $0.lowercased() },
                "channels": assets.map { "prices.\($0)" },
                "isConnected": isConnected
            ],
            hypothesisId: "PRICE-1,PRICE-3"
        )
        // #endregion
        
        guard isConnected else {
            // Queue channels for when connected
            for asset in assets {
                subscribedChannels.insert("prices.\(asset)")
            }
            return
        }
        
        // Try batching all channels in one subscription message
        let channels = assets.map { "prices.\($0)" }
        
        // Try format: {"type": "subscribe", "channels": ["prices.BTC", "prices.ETH", ...]}
        let batchMessage: [String: Any] = [
            "type": "subscribe",
            "channels": channels
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: batchMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔵 [DEBUG] Sending batched subscription for \(channels.count) channels")
            socket?.write(string: jsonString)
            
            // Also add to subscribed channels set
            for channel in channels {
                subscribedChannels.insert(channel)
            }
        } else {
            // Fallback to individual subscriptions
            print("🔵 [DEBUG] Falling back to individual subscriptions")
            for asset in assets {
                let channel = "prices.\(asset)"
                subscribe(to: channel)
            }
        }
    }
    
    func subscribeToPositions(userId: String) {
        let channel = "positions.\(userId)"
        subscribe(to: channel)
    }
    
    func subscribeToFills(orderId: String) {
        let channel = "fills.\(orderId)"
        subscribe(to: channel)
    }
    
    func subscribeToOpenOrders(userId: String) {
        let channel = "open-orders.\(userId)"
        subscribe(to: channel)
    }
    
    func subscribeToMarketData() {
        let channel = "market-data"
        subscribe(to: channel)
        print("🔵 [DEBUG] Subscribed to market-data channel")
    }
    
    func subscribeToTradeHistories(userId: String) {
        let channel = "trade-histories.\(userId)"
        subscribe(to: channel)
    }
    
    func subscribeToTWAPDetails(orderId: String) {
        let channel = "twap-details.\(orderId)"
        subscribe(to: channel)
    }
    
    func subscribeToNotifications(userId: String) {
        let channel = "notifications.\(userId)"
        subscribe(to: channel)
    }
    
    func subscribeToAccountSummary(userId: String) {
        let channel = "account-summary.\(userId)"
        subscribe(to: channel)
    }
    
    func unsubscribeFromPrices(assets: [String]) {
        for asset in assets {
            let channel = "prices.\(asset)"
            unsubscribe(from: channel)
        }
    }
    
    private func subscribe(to channel: String) {
        // #region agent log
        DebugLogger.log(
            location: "WebSocketService.swift:198",
            message: "Subscribing to WebSocket channel",
            data: [
                "channel": channel,
                "isConnected": isConnected,
                "subscribedChannelsCount": subscribedChannels.count
            ],
            hypothesisId: "PRICE-3"
        )
        // #endregion
        
        guard isConnected else {
            subscribedChannels.insert(channel)
            return
        }
        
        let message = WebSocketMessage(
            type: "subscribe",
            channel: channel
        )
        
        send(message)
        subscribedChannels.insert(channel)
    }
    
    private func unsubscribe(from channel: String) {
        guard isConnected else {
            subscribedChannels.remove(channel)
            return
        }
        
        let message = WebSocketMessage(
            type: "unsubscribe",
            channel: channel
        )
        
        send(message)
        subscribedChannels.remove(channel)
    }
    
    private func resubscribeAll() {
        // #region agent log
        DebugLogger.log(
            location: "WebSocketService.swift:228",
            message: "Resubscribing to all channels",
            data: [
                "channelsCount": subscribedChannels.count,
                "channels": Array(subscribedChannels)
            ],
            hypothesisId: "PRICE-3"
        )
        // #endregion
        
        for channel in subscribedChannels {
            let message = WebSocketMessage(
                type: "subscribe",
                channel: channel
            )
            send(message)
        }
    }
    
    // MARK: - Sending
    private func send(_ message: WebSocketMessage) {
        guard let socket = socket, isConnected else {
            // #region agent log
            DebugLogger.log(
                location: "WebSocketService.swift:239",
                message: "WebSocket send blocked - not connected",
                data: [
                    "messageType": message.type,
                    "channel": message.channel,
                    "isConnected": isConnected,
                    "hasSocket": socket != nil
                ],
                hypothesisId: "PRICE-3"
            )
            // #endregion
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            if let string = String(data: data, encoding: .utf8) {
                // #region agent log
                DebugLogger.log(
                    location: "WebSocketService.swift:245",
                    message: "WebSocket message sent",
                    data: [
                        "messageType": message.type,
                        "channel": message.channel,
                        "messageJson": string
                    ],
                    hypothesisId: "PRICE-3"
                )
                // #endregion
                socket.write(string: string)
            }
        } catch {
            print("WebSocket encoding error: \(error)")
            // #region agent log
            DebugLogger.log(
                location: "WebSocketService.swift:248",
                message: "WebSocket encoding error",
                data: [
                    "error": error.localizedDescription,
                    "messageType": message.type,
                    "channel": message.channel
                ],
                hypothesisId: "PRICE-4"
            )
            // #endregion
        }
    }
    
    // MARK: - Ping/Pong
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.socket?.write(ping: Data())
            }
        }
    }
    
    // MARK: - Message Handling
    private func handleMessage(_ text: String) {
        // #region agent log
        DebugLogger.log(
            location: "WebSocketService.swift:335",
            message: "WebSocket message received",
            data: [
                "messageLength": text.count,
                "messagePreview": String(text.prefix(200)),
                "hasAuthToken": authToken != nil
            ],
            hypothesisId: "PRICE-1,PRICE-2,PRICE-3"
        )
        // #endregion
        
        guard let data = text.data(using: .utf8) else { return }
        
        // First, try to parse as JSON dictionary to inspect structure
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Not valid JSON - ignore silently (could be ping/pong or other protocol messages)
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Check if message has a "type" field
        if let messageType = json["type"] as? String {
            // #region agent log
            DebugLogger.log(
                location: "WebSocketService.swift:354",
                message: "WebSocket message type decoded",
                data: [
                    "messageType": messageType,
                    "rawMessage": text
                ],
                hypothesisId: "PRICE-2,PRICE-4"
            )
            // #endregion
            
            do {
                switch messageType {
                case "price":
                    let update = try decoder.decode(PriceUpdate.self, from: data)
                    
                    // #region agent log
                    DebugLogger.log(
                        location: "WebSocketService.swift:374",
                        message: "PriceUpdate decoded successfully",
                        data: [
                            "assetId": update.assetId,
                            "assetIdLowercase": update.assetId.lowercased(),
                            "price": update.price,
                            "volume24h": update.volume24h,
                            "change24h": update.change24h
                        ],
                        hypothesisId: "PRICE-1,PRICE-2"
                    )
                    // #endregion
                    
                    priceUpdates.send(update)
                    
                case "position":
                    let update = try decoder.decode(PositionUpdate.self, from: data)
                    positionUpdates.send(update)
                    
                case "fill":
                    let update = try decoder.decode(FillUpdate.self, from: data)
                    fillUpdates.send(update)
                    
                case "open-order", "openOrder":
                    let update = try decoder.decode(OpenOrderUpdate.self, from: data)
                    openOrderUpdates.send(update)
                    
                case "trade-history", "tradeHistory":
                    let update = try decoder.decode(TradeHistoryUpdate.self, from: data)
                    tradeHistoryUpdates.send(update)
                    
                case "twap-details", "twapDetails":
                    let update = try decoder.decode(TWAPDetailsUpdate.self, from: data)
                    twapDetailsUpdates.send(update)
                    
                case "notification":
                    let update = try decoder.decode(NotificationUpdate.self, from: data)
                    notificationUpdates.send(update)
                    
                case "account-summary", "accountSummary":
                    let update = try decoder.decode(AccountSummaryUpdate.self, from: data)
                    accountSummaryUpdates.send(update)
                    
                case "market-data", "marketData":
                    let update = try decoder.decode(MarketDataUpdate.self, from: data)
                    marketDataUpdates.send(update)
                    
                case "error":
                    let errorMessage = try decoder.decode(WebSocketErrorMessage.self, from: data)
                    lastError = errorMessage.message
                    
                case "pong", "ping", "connected", "subscribed", "unsubscribed":
                    // Protocol messages - ignore silently
                    break
                    
                default:
                    // Unknown message type - log once per type
                    print("🔵 [DEBUG] WebSocket unknown message type: \(messageType)")
                }
            } catch {
                print("WebSocket decoding error for type '\(messageType)': \(error)")
            }
        } else {
            // Message doesn't have "type" field - try to detect message type from structure
            // This handles Pear Protocol WebSocket messages that may use different field names
            
            if let event = json["event"] as? String {
                // Handle event-based messages (e.g., { "event": "subscribed", "channel": "..." })
                switch event {
                case "subscribed", "unsubscribed", "pong", "ping", "connected":
                    // Protocol acknowledgments - ignore silently
                    break
                case "error":
                    if let message = json["message"] as? String {
                        lastError = message
                        print("🔵 [DEBUG] WebSocket error: \(message)")
                    }
                default:
                    print("🔵 [DEBUG] WebSocket unknown event: \(event)")
                }
            } else if json["channel"] != nil || json["data"] != nil {
                // Looks like a channel message with data - log structure for debugging
                print("🔵 [DEBUG] WebSocket channel message received (no type field)")
                if let channel = json["channel"] as? String {
                    print("🔵 [DEBUG] Channel: \(channel)")
                }
            } else {
                // Unknown message format - log first 200 chars for debugging (only once)
                let preview = String(text.prefix(200))
                print("🔵 [DEBUG] WebSocket message without type field: \(preview)")
            }
        }
    }
}

// MARK: - WebSocket Delegate
extension WebSocketService: WebSocketDelegate {
    nonisolated func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
        Task { @MainActor in
            switch event {
            case .connected:
                isConnected = true
                connectionState = .connected
                reconnectAttempts = 0
                lastError = nil
                print("🔵 [DEBUG] WebSocket connected successfully")
                
                // #region agent log
                DebugLogger.log(
                    location: "WebSocketService.swift:449",
                    message: "WebSocket connected - about to resubscribe",
                    data: [
                        "subscribedChannelsCount": subscribedChannels.count,
                        "subscribedChannels": Array(subscribedChannels),
                        "hasAuthToken": authToken != nil
                    ],
                    hypothesisId: "PRICE-3"
                )
                // #endregion
                
                startPingTimer()
                resubscribeAll()
                print("🔵 [DEBUG] WebSocket resubscribed to \(subscribedChannels.count) channels")
                
            case .disconnected(let reason, let code):
                isConnected = false
                print("WebSocket disconnected: \(reason) (code: \(code))")
                reconnect()
                
            case .text(let text):
                handleMessage(text)
                
            case .binary(let data):
                if let text = String(data: data, encoding: .utf8) {
                    handleMessage(text)
                }
                
            case .ping:
                socket?.write(pong: Data())
                
            case .pong:
                break
                
            case .viabilityChanged(let viable):
                if !viable {
                    reconnect()
                }
                
            case .reconnectSuggested(let suggested):
                if suggested {
                    reconnect()
                }
                
            case .cancelled:
                isConnected = false
                connectionState = .disconnected
                
            case .error(let error):
                lastError = error?.localizedDescription
                isConnected = false
                reconnect()
                
            case .peerClosed:
                isConnected = false
                reconnect()
            }
        }
    }
}

// MARK: - WebSocket Message Models
struct WebSocketMessage: Codable {
    let type: String
    let channel: String
}

struct WebSocketBaseMessage: Codable {
    let type: String
}

struct WebSocketErrorMessage: Codable {
    let type: String
    let message: String
    let code: Int?
}

// MARK: - Update Models
struct PriceUpdate: Codable {
    let type: String
    let assetId: String
    let price: Double
    let change24h: Double
    let changePercent24h: Double
    let volume24h: Double
    let timestamp: Date
}

struct PositionUpdate: Codable {
    let type: String
    let positionId: String
    let currentValue: Double
    let unrealizedPnL: Double
    let unrealizedPnLPercent: Double
    let timestamp: Date
}

struct FillUpdate: Codable {
    let type: String
    let orderId: String
    let positionId: String
    let status: TradeStatus
    let executedLegs: [ExecutedLeg]?
    let totalFees: Double
    let timestamp: Date
    let message: String?
}

// MARK: - Additional WebSocket Update Models
struct OpenOrderUpdate: Codable {
    let type: String
    let orderId: String
    let status: OrderStatus
    let filledSize: Double
    let remainingSize: Double
    let timestamp: Date
}

struct TradeHistoryUpdate: Codable {
    let type: String
    let tradeId: String
    let positionId: String
    let status: TradeStatus
    let realizedPnL: Double
    let timestamp: Date
}

struct TWAPDetailsUpdate: Codable {
    let type: String
    let orderId: String
    let status: TWAPStatus
    let filledSize: Double
    let remainingSize: Double
    let progress: Double
    let nextFillAt: Date?
    let timestamp: Date
}

struct NotificationUpdate: Codable {
    let type: String
    let notification: PearNotification  // Using full name to avoid conflict with Foundation.Notification
    let timestamp: Date
}

struct AccountSummaryUpdate: Codable {
    let type: String
    let totalPortfolioValue: Double
    let totalUnrealizedPnL: Double
    let totalMarginUsed: Double
    let availableMargin: Double
    let timestamp: Date
}

struct MarketDataUpdate: Codable {
    let type: String
    let marketData: MarketDataResponse
    let timestamp: Date
}
