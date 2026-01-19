import Foundation
@testable import PearProtocolApp

// MARK: - Mock API Service
/// Mock implementation of PearAPIService for testing
actor MockAPIService {
    
    // MARK: - Configuration
    var shouldSucceed = true
    var delayInSeconds: TimeInterval = 0
    var errorToThrow: Error?
    
    // MARK: - Recorded Calls
    private(set) var fetchActiveAssetsCalled = false
    private(set) var createAgentWalletCalled = false
    private(set) var approveAgentWalletCalled = false
    private(set) var executeTradeC = false
    private(set) var fetchPositionsCalled = false
    private(set) var closePositionCalled = false
    
    // MARK: - Mock Responses
    var mockActiveAssetsResponse: ActiveAssetsResponse?
    var mockAgentWalletCreateResponse: AgentWalletCreateResponse?
    var mockAgentWalletApproveResponse: AgentWalletApproveResponse?
    var mockTradeExecuteResponse: TradeExecuteResponse?
    var mockPositionsResponse: PositionsResponse?
    var mockClosePositionResponse: ClosePositionResponse?
    
    // MARK: - Agent Wallet
    func getAgentWalletStatus(userAddress: String) async throws -> AgentWalletStatusResponse {
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw PearAPIError.serverError
        }
        
        return AgentWalletStatusResponse(
            agentWallet: TestFixtures.testAgentWallet,
            isActive: true,
            message: "Agent wallet active",
            authToken: TestFixtures.testAuthToken,
            clientToken: nil,
            token: nil
        )
    }
    
    func createAgentWallet(request: AgentWalletCreateRequest) async throws -> AgentWalletCreateResponse {
        createAgentWalletCalled = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw PearAPIError.serverError
        }
        
        return mockAgentWalletCreateResponse ?? AgentWalletCreateResponse(
            agentWalletAddress: TestFixtures.testAgentWallet.address,
            messageToSign: "Test message to sign",
            expiresAt: TestFixtures.testAgentWallet.expiresAt,
            nonce: "test_nonce",
            authToken: TestFixtures.testAuthToken,
            clientToken: nil,
            token: nil
        )
    }
    
    func approveAgentWallet(request: AgentWalletApproveRequest) async throws -> AgentWalletApproveResponse {
        approveAgentWalletCalled = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw PearAPIError.serverError
        }
        
        return mockAgentWalletApproveResponse ?? AgentWalletApproveResponse(
            success: true,
            agentWallet: TestFixtures.testAgentWallet,
            message: "Agent wallet approved",
            authToken: TestFixtures.testAuthToken,
            clientToken: nil,
            token: nil
        )
    }
    
    // MARK: - Assets
    func fetchActiveAssets() async throws -> ActiveAssetsResponse {
        fetchActiveAssetsCalled = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw PearAPIError.serverError
        }
        
        return mockActiveAssetsResponse ?? TestFixtures.testActiveAssetsResponse
    }
    
    // MARK: - Trading
    func executeTrade(request: TradeExecuteRequest) async throws -> TradeExecuteResponse {
        executeTradeC = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw PearAPIError.serverError
        }
        
        return mockTradeExecuteResponse ?? TestFixtures.testTradeExecuteResponse
    }
    
    func closePosition(request: ClosePositionRequest) async throws -> ClosePositionResponse {
        closePositionCalled = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw PearAPIError.serverError
        }
        
        return mockClosePositionResponse ?? ClosePositionResponse(
            orderId: "order_close_123",
            positionId: "pos_123",
            status: .filled,
            realizedPnL: 50,
            fees: 1.0,
            timestamp: Date(),
            message: "Position closed successfully"
        )
    }
    
    // MARK: - Positions
    func fetchPositions(agentWalletAddress: String) async throws -> PositionsResponse {
        fetchPositionsCalled = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw PearAPIError.serverError
        }
        
        return mockPositionsResponse ?? TestFixtures.testPositionsResponse
    }
    
    // MARK: - Reset
    func reset() {
        shouldSucceed = true
        delayInSeconds = 0
        errorToThrow = nil
        fetchActiveAssetsCalled = false
        createAgentWalletCalled = false
        approveAgentWalletCalled = false
        executeTradeC = false
        fetchPositionsCalled = false
        closePositionCalled = false
    }
}
