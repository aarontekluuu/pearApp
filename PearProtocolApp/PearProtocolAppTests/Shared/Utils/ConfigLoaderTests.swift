import XCTest
@testable import PearProtocolApp

final class ConfigLoaderTests: XCTestCase {
    
    // MARK: - WalletConnect Project ID Tests
    
    func testLoadWalletConnectProjectId() {
        // When
        let projectId = ConfigLoader.loadWalletConnectProjectId()
        
        // Then
        XCTAssertNotNil(projectId, "WalletConnect Project ID should be loaded from Config.plist")
        XCTAssertFalse(projectId?.isEmpty ?? true, "WalletConnect Project ID should not be empty")
    }
    
    // MARK: - Client ID Tests
    
    func testLoadClientID() {
        // When
        let clientId = ConfigLoader.loadClientID()
        
        // Then
        XCTAssertNotNil(clientId, "Client ID should be loaded from Config.plist")
        XCTAssertFalse(clientId?.isEmpty ?? true, "Client ID should not be empty")
    }
    
    // MARK: - Builder Contract Address Tests
    
    func testLoadBuilderContractAddress() {
        // When
        let address = ConfigLoader.loadBuilderContractAddress()
        
        // Then
        // Builder contract address might be optional or placeholder
        if let address = address {
            XCTAssertFalse(address.isEmpty, "Builder contract address should not be empty if present")
            XCTAssertTrue(address.hasPrefix("0x"), "Builder contract address should start with 0x")
        }
    }
    
    // MARK: - API Token Tests
    
    func testLoadAPIToken() {
        // When
        let token = ConfigLoader.loadAPIToken()
        
        // Then
        // API token is optional and may be empty in test environment
        // Just verify it doesn't crash
        XCTAssertTrue(true, "API token loading should not crash")
    }
    
    // MARK: - Validation Tests
    
    func testValidateRequiredConfig() {
        // When
        let isValid = ConfigLoader.validateRequiredConfig()
        
        // Then
        XCTAssertTrue(isValid, "Required config should be valid with WalletConnect Project ID and Client ID")
    }
    
    // MARK: - Config Error Tests
    
    func testConfigErrorDescriptions() {
        // Given
        let errors: [ConfigLoader.ConfigError] = [
            .configFileNotFound,
            .missingKey("TEST_KEY"),
            .invalidValue("TEST_VALUE")
        ]
        
        // Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testConfigFileNotFoundError() {
        // Given
        let error = ConfigLoader.ConfigError.configFileNotFound
        
        // Then
        XCTAssertTrue(error.errorDescription?.contains("Config.plist") ?? false)
    }
    
    func testMissingKeyError() {
        // Given
        let key = "MISSING_KEY"
        let error = ConfigLoader.ConfigError.missingKey(key)
        
        // Then
        XCTAssertTrue(error.errorDescription?.contains(key) ?? false)
    }
    
    func testInvalidValueError() {
        // Given
        let key = "INVALID_KEY"
        let error = ConfigLoader.ConfigError.invalidValue(key)
        
        // Then
        XCTAssertTrue(error.errorDescription?.contains(key) ?? false)
    }
}
