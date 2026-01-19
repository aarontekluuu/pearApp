import Foundation
import Combine
@testable import PearProtocolApp

// MARK: - Mock WebSocket Service
/// Mock implementation of WebSocketService for testing
@MainActor
class MockWebSocketService: ObservableObject {
    
    // MARK: - Published State
    @Published var isConnected: Bool = false
    @Published var connectionState: WebSocketService.ConnectionState = .disconnected
    @Published var lastError: String?
    
    // MARK: - Publishers
    let priceUpdates = PassthroughSubject<PriceUpdate, Never>()
    let positionUpdates = PassthroughSubject<PositionUpdate, Never>()
    let fillUpdates = PassthroughSubject<FillUpdate, Never>()
    
    // MARK: - Configuration
    var shouldSucceed = true
    var autoConnect = true
    
    // MARK: - Recorded Calls
    private(set) var connectCalled = false
    private(set) var disconnectCalled = false
    private(set) var subscribedChannels: Set<String> = []
    
    // MARK: - Connection
    func connect() {
        connectCalled = true
        
        if shouldSucceed && autoConnect {
            isConnected = true
            connectionState = .connected
        } else {
            isConnected = false
            connectionState = .disconnected
            lastError = "Mock connection failed"
        }
    }
    
    func disconnect() {
        disconnectCalled = true
        isConnected = false
        connectionState = .disconnected
        subscribedChannels.removeAll()
    }
    
    // MARK: - Subscriptions
    func subscribeToPrices(assets: [String]) {
        for asset in assets {
            subscribedChannels.insert("prices.\(asset)")
        }
    }
    
    func subscribeToPositions(userId: String) {
        subscribedChannels.insert("positions.\(userId)")
    }
    
    func subscribeToFills(orderId: String) {
        subscribedChannels.insert("fills.\(orderId)")
    }
    
    func unsubscribeFromPrices(assets: [String]) {
        for asset in assets {
            subscribedChannels.remove("prices.\(asset)")
        }
    }
    
    // MARK: - Mock Data Injection
    func simulatePriceUpdate(assetId: String, price: Double) {
        let update = PriceUpdate(
            type: "price",
            assetId: assetId,
            price: price,
            change24h: 5.0,
            changePercent24h: 2.0,
            volume24h: 1_000_000,
            timestamp: Date()
        )
        priceUpdates.send(update)
    }
    
    func simulatePositionUpdate(positionId: String, currentValue: Double, pnl: Double) {
        let update = PositionUpdate(
            type: "position",
            positionId: positionId,
            currentValue: currentValue,
            unrealizedPnL: pnl,
            unrealizedPnLPercent: (pnl / currentValue) * 100,
            timestamp: Date()
        )
        positionUpdates.send(update)
    }
    
    func simulateFillUpdate(orderId: String, positionId: String, status: TradeStatus) {
        let update = FillUpdate(
            type: "fill",
            orderId: orderId,
            positionId: positionId,
            status: status,
            executedLegs: nil,
            totalFees: 1.0,
            timestamp: Date(),
            message: "Mock fill update"
        )
        fillUpdates.send(update)
    }
    
    // MARK: - Reset
    func reset() {
        isConnected = false
        connectionState = .disconnected
        lastError = nil
        shouldSucceed = true
        autoConnect = true
        connectCalled = false
        disconnectCalled = false
        subscribedChannels.removeAll()
    }
}
