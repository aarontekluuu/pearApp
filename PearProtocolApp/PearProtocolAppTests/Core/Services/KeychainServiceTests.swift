import XCTest
@testable import PearProtocolApp

@MainActor
final class KeychainServiceTests: XCTestCase {
    
    var sut: KeychainService!
    
    override func setUp() async throws {
        try await super.setUp()
        // Note: KeychainService is a singleton, so we'll clear it before each test
        sut = KeychainService.shared
        sut.clearAll()
    }
    
    override func tearDown() async throws {
        sut.clearAll()
        try await super.tearDown()
    }
    
    // MARK: - Auth Token Tests
    
    func testAuthTokenStorage() {
        // Given
        let testToken = "test_auth_token_123"
        
        // When
        sut.authToken = testToken
        
        // Then
        XCTAssertEqual(sut.authToken, testToken)
    }
    
    func testAuthTokenRemoval() {
        // Given
        sut.authToken = "test_token"
        
        // When
        sut.authToken = nil
        
        // Then
        XCTAssertNil(sut.authToken)
    }
    
    func testRefreshTokenStorage() {
        // Given
        let testToken = "test_refresh_token_456"
        
        // When
        sut.refreshToken = testToken
        
        // Then
        XCTAssertEqual(sut.refreshToken, testToken)
    }
    
    func testTokenExpiryStorage() {
        // Given
        let expiryDate = Date().addingTimeInterval(3600)
        
        // When
        sut.tokenExpiresAt = expiryDate
        
        // Then
        XCTAssertNotNil(sut.tokenExpiresAt)
        // Allow 1 second tolerance for date comparison
        XCTAssertEqual(sut.tokenExpiresAt?.timeIntervalSince1970 ?? 0, expiryDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Agent Wallet Tests
    
    func testAgentWalletAddressStorage() {
        // Given
        let testAddress = "0x1234567890123456789012345678901234567890"
        
        // When
        sut.agentWalletAddress = testAddress
        
        // Then
        XCTAssertEqual(sut.agentWalletAddress, testAddress)
    }
    
    func testAgentWalletExpiryStorage() {
        // Given
        let expiryDate = Date().addingTimeInterval(Double(Constants.AgentWallet.expiryDays * 86400))
        
        // When
        sut.agentWalletExpiry = expiryDate
        
        // Then
        XCTAssertNotNil(sut.agentWalletExpiry)
        XCTAssertEqual(sut.agentWalletExpiry?.timeIntervalSince1970 ?? 0, expiryDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Connected Wallet Tests
    
    func testConnectedWalletAddressStorage() {
        // Given
        let testAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        
        // When
        sut.connectedWalletAddress = testAddress
        
        // Then
        XCTAssertEqual(sut.connectedWalletAddress, testAddress)
    }
    
    // MARK: - Builder Approval Tests
    
    func testBuilderApprovalStorage() {
        // Given
        let approved = true
        
        // When
        sut.isBuilderApproved = approved
        
        // Then
        XCTAssertTrue(sut.isBuilderApproved)
    }
    
    func testBuilderApprovalDefaultValue() {
        // Given - fresh keychain
        sut.clearAll()
        
        // Then
        XCTAssertFalse(sut.isBuilderApproved)
    }
    
    // MARK: - Onboarding Status Tests
    
    func testOnboardingCompletionStorage() {
        // Given
        let completed = true
        
        // When
        sut.hasCompletedOnboarding = completed
        
        // Then
        XCTAssertTrue(sut.hasCompletedOnboarding)
    }
    
    // MARK: - Generic Storage Tests
    
    func testGenericSetAndGet() {
        // Given
        let key = "test_key"
        let value = "test_value"
        
        // When
        sut.set(value, forKey: key)
        let retrieved = sut.get(forKey: key)
        
        // Then
        XCTAssertEqual(retrieved, value)
    }
    
    func testGenericGetNonExistentKey() {
        // When
        let retrieved = sut.get(forKey: "non_existent_key")
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Validation Tests
    
    func testValidateStoredDataWithFullData() {
        // Given
        sut.authToken = "test_token"
        sut.agentWalletAddress = "0x123"
        sut.connectedWalletAddress = "0x456"
        sut.isBuilderApproved = true
        sut.agentWalletExpiry = Date().addingTimeInterval(86400 * 30) // 30 days
        
        // When
        let status = sut.validateStoredData()
        
        // Then
        XCTAssertTrue(status.hasAuthToken)
        XCTAssertTrue(status.hasAgentWallet)
        XCTAssertTrue(status.hasConnectedWallet)
        XCTAssertTrue(status.isBuilderApproved)
        XCTAssertFalse(status.isAgentWalletExpired)
        XCTAssertTrue(status.isFullyConfigured)
    }
    
    func testValidateStoredDataWithExpiredAgentWallet() {
        // Given
        sut.authToken = "test_token"
        sut.agentWalletAddress = "0x123"
        sut.connectedWalletAddress = "0x456"
        sut.isBuilderApproved = true
        sut.agentWalletExpiry = Date().addingTimeInterval(-86400) // Yesterday
        
        // When
        let status = sut.validateStoredData()
        
        // Then
        XCTAssertTrue(status.isAgentWalletExpired)
        XCTAssertFalse(status.isFullyConfigured)
    }
    
    func testValidateStoredDataNeedsRefresh() {
        // Given
        sut.authToken = "test_token"
        sut.agentWalletAddress = "0x123"
        sut.connectedWalletAddress = "0x456"
        sut.isBuilderApproved = true
        sut.agentWalletExpiry = Date().addingTimeInterval(86400 * 5) // 5 days (less than threshold)
        
        // When
        let status = sut.validateStoredData()
        
        // Then
        XCTAssertTrue(status.needsAgentWalletRefresh)
    }
    
    func testValidateStoredDataIncomplete() {
        // Given - only partial data
        sut.authToken = "test_token"
        
        // When
        let status = sut.validateStoredData()
        
        // Then
        XCTAssertTrue(status.hasAuthToken)
        XCTAssertFalse(status.hasAgentWallet)
        XCTAssertFalse(status.hasConnectedWallet)
        XCTAssertFalse(status.isFullyConfigured)
    }
    
    // MARK: - Clear All Tests
    
    func testClearAll() {
        // Given
        sut.authToken = "test_token"
        sut.agentWalletAddress = "0x123"
        sut.connectedWalletAddress = "0x456"
        sut.isBuilderApproved = true
        
        // When
        sut.clearAll()
        
        // Then
        XCTAssertNil(sut.authToken)
        XCTAssertNil(sut.agentWalletAddress)
        XCTAssertNil(sut.connectedWalletAddress)
        XCTAssertFalse(sut.isBuilderApproved)
    }
    
    // MARK: - Persistence Tests
    
    func testDataPersistsAcrossAccess() {
        // Given
        let testToken = "persistent_token"
        sut.authToken = testToken
        
        // When - access through singleton again
        let retrievedToken = KeychainService.shared.authToken
        
        // Then
        XCTAssertEqual(retrievedToken, testToken)
    }
}
