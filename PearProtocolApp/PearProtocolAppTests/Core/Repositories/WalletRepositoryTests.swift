import XCTest
@testable import PearProtocolApp

@MainActor
final class WalletRepositoryTests: XCTestCase {
    
    var sut: WalletRepository!
    var mockWalletService: MockWalletService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockWalletService = MockWalletService()
        sut = WalletRepository()
        // Note: WalletRepository uses singleton services, so we can't inject mocks easily
        // These tests will focus on state management
    }
    
    override func tearDown() async throws {
        sut = nil
        mockWalletService = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.agentWalletAddress)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isApproved)
    }
    
    // MARK: - Builder Approval Tests
    
    func testSetBuilderApproved() {
        // When
        sut.setBuilderApproved(true)
        
        // Then
        XCTAssertTrue(sut.isApproved)
    }
    
    func testSetBuilderApprovedPersistsToKeychain() {
        // When
        sut.setBuilderApproved(true)
        
        // Then
        XCTAssertTrue(KeychainService.shared.isBuilderApproved)
    }
    
    func testSetBuilderApprovedFalse() {
        // Given
        sut.setBuilderApproved(true)
        
        // When
        sut.setBuilderApproved(false)
        
        // Then
        XCTAssertFalse(sut.isApproved)
        XCTAssertFalse(KeychainService.shared.isBuilderApproved)
    }
    
    // MARK: - Agent Wallet Status Tests
    
    func testCheckAgentWalletStatusWithNoAddress() async {
        // When
        await sut.checkAgentWalletStatus()
        
        // Then
        XCTAssertNil(sut.agentWalletAddress)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorProperty() {
        // Given
        let testError = "Test error message"
        
        // When
        sut.error = testError
        
        // Then
        XCTAssertEqual(sut.error, testError)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingState() {
        // When
        sut.isLoading = true
        
        // Then
        XCTAssertTrue(sut.isLoading)
        
        // When
        sut.isLoading = false
        
        // Then
        XCTAssertFalse(sut.isLoading)
    }
}
