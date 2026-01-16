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
    
    // MARK: - Private Properties
    private var socket: WebSocket?
    private var reconnectAttempts = 0
    private var maxReconnectAttempts = 5
    private var reconnectDelay: TimeInterval = 1.0
    private var pingTimer: Timer?
    private var subscribedChannels: Set<String> = []
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
    }
    
    private init() {}
    
    // MARK: - Connection
    func connect() {
        guard socket == nil else { return }
        
        connectionState = .connecting
        
        var request = URLRequest(url: URL(string: Constants.API.webSocketURL)!)
        request.timeoutInterval = 10
        
        // Add auth token if available
        if let token = ConfigLoader.loadAPIToken() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        socket?.disconnect()
        socket = nil
        isConnected = false
        connectionState = .disconnected
        subscribedChannels.removeAll()
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
        for asset in assets {
            let channel = "prices.\(asset)"
            subscribe(to: channel)
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
    
    func unsubscribeFromPrices(assets: [String]) {
        for asset in assets {
            let channel = "prices.\(asset)"
            unsubscribe(from: channel)
        }
    }
    
    private func subscribe(to channel: String) {
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
        guard let socket = socket, isConnected else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            if let string = String(data: data, encoding: .utf8) {
                socket.write(string: string)
            }
        } catch {
            print("WebSocket encoding error: \(error)")
        }
    }
    
    // MARK: - Ping/Pong
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.socket?.write(ping: Data())
        }
    }
    
    // MARK: - Message Handling
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let baseMessage = try decoder.decode(WebSocketBaseMessage.self, from: data)
            
            switch baseMessage.type {
            case "price":
                let update = try decoder.decode(PriceUpdate.self, from: data)
                priceUpdates.send(update)
                
            case "position":
                let update = try decoder.decode(PositionUpdate.self, from: data)
                positionUpdates.send(update)
                
            case "fill":
                let update = try decoder.decode(FillUpdate.self, from: data)
                fillUpdates.send(update)
                
            case "error":
                let errorMessage = try decoder.decode(WebSocketErrorMessage.self, from: data)
                lastError = errorMessage.message
                
            default:
                break
            }
        } catch {
            print("WebSocket decoding error: \(error)")
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
                startPingTimer()
                resubscribeAll()
                
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
