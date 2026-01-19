import Foundation
import Combine
@testable import PearProtocolApp

// MARK: - Mock Wallet Service
/// Mock implementation of WalletService for testing
@MainActor
class MockWalletService: ObservableObject {
    
    // MARK: - Published State
    @Published var isConnected: Bool = false
    @Published var connectedAddress: String?
    @Published var chainId: Int?
    @Published var isConnecting: Bool = false
    @Published var connectionError: String?
    @Published var connectionStage: ConnectionStage = .idle
    
    // MARK: - Configuration
    var shouldSucceed = true
    var delayInSeconds: TimeInterval = 0
    var errorToThrow: Error?
    
    // MARK: - Recorded Calls
    private(set) var connectCalled = false
    private(set) var disconnectCalled = false
    private(set) var signMessageCalled = false
    private(set) var signEIP712MessageCalled = false
    private(set) var sendTransactionCalled = false
    
    // MARK: - Mock Responses
    var mockSignature: String?
    var mockTransactionHash: String?
    
    // MARK: - Connection
    func connect(walletType: WalletType? = nil) async throws -> String {
        connectCalled = true
        isConnecting = true
        connectionStage = .connecting
        
        if let error = errorToThrow {
            isConnecting = false
            connectionStage = .failed(error.localizedDescription)
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            isConnecting = false
            connectionStage = .failed("Connection failed")
            throw WalletError.connectionFailed("Mock connection failed")
        }
        
        isConnected = true
        connectedAddress = TestFixtures.testWalletAddress
        chainId = TestFixtures.testChainId
        isConnecting = false
        connectionStage = .connected
        
        return TestFixtures.testWalletAddress
    }
    
    func disconnect() async {
        disconnectCalled = true
        isConnected = false
        connectedAddress = nil
        chainId = nil
        connectionStage = .idle
    }
    
    func clearAllConnections() async {
        await disconnect()
    }
    
    // MARK: - Signing
    func signMessage(_ message: String) async throws -> String {
        signMessageCalled = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw WalletError.signingFailed("Mock signing failed")
        }
        
        return mockSignature ?? "0xmocksignature"
    }
    
    func signEIP712Message(
        domain: EIP712Domain,
        types: EIP712Types,
        primaryType: String,
        message: [String: AnyCodable]
    ) async throws -> String {
        signEIP712MessageCalled = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw WalletError.signingFailed("Mock EIP712 signing failed")
        }
        
        return mockSignature ?? "0xmockeip712signature"
    }
    
    // MARK: - Transactions
    func sendTransaction(to: String, value: String, data: String) async throws -> String {
        sendTransactionCalled = true
        
        if let error = errorToThrow {
            throw error
        }
        
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }
        
        if !shouldSucceed {
            throw WalletError.transactionFailed("Mock transaction failed")
        }
        
        return mockTransactionHash ?? "0xmocktxhash"
    }
    
    // MARK: - Wallet Detection
    func checkInstalledWallets() async -> [WalletType] {
        return [.metamask, .rainbow]
    }
    
    // MARK: - Reset
    func reset() {
        isConnected = false
        connectedAddress = nil
        chainId = nil
        isConnecting = false
        connectionError = nil
        connectionStage = .idle
        shouldSucceed = true
        delayInSeconds = 0
        errorToThrow = nil
        connectCalled = false
        disconnectCalled = false
        signMessageCalled = false
        signEIP712MessageCalled = false
        sendTransactionCalled = false
        mockSignature = nil
        mockTransactionHash = nil
    }
}
