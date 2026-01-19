import Foundation
import WalletConnectSign  // For AnyCodable

// MARK: - EIP-712 Message Request
struct EIP712MessageRequest: Codable {
    let address: String
    let clientId: String
}

// MARK: - EIP-712 Message Response
struct EIP712MessageResponse: Codable {
    let message: [String: AnyCodable]  // Message is a dictionary, not a string
    let domain: EIP712Domain
    let types: EIP712Types
    let primaryType: String
}

// MARK: - EIP-712 Domain
struct EIP712Domain: Codable {
    let name: String
    let version: String
    let chainId: Int
    let verifyingContract: String?
}

// MARK: - EIP-712 Types (flexible to accept any type names from API)
struct EIP712Types: Codable {
    let types: [String: [EIP712TypeField]]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        types = try container.decode([String: [EIP712TypeField]].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(types)
    }
    
    // Convenience accessors
    var eip712Domain: [EIP712TypeField]? {
        types["EIP712Domain"]
    }
}

// MARK: - EIP-712 Type Field
struct EIP712TypeField: Codable {
    let name: String
    let type: String
}

// MARK: - Login Request
struct LoginRequest: Codable {
    let address: String
    let clientId: String
    let method: String
    let details: LoginDetails
    
    struct LoginDetails: Codable {
        let signature: String
        let timestamp: Int  // Unix timestamp used in the signed message (required by API)
    }
    
    init(address: String, clientId: String, signature: String, timestamp: Int, method: String = "eip712") {
        self.address = address
        self.clientId = clientId
        self.method = method
        self.details = LoginDetails(signature: signature, timestamp: timestamp)
    }
}

// MARK: - Login Response
struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int // seconds until access token expires
    let tokenType: String
    
    // API returns camelCase (accessToken, refreshToken, expiresIn, tokenType)
    // Decoder uses .convertFromSnakeCase, but API already returns camelCase
    // So we use CodingKeys to explicitly map to camelCase (overriding snake_case conversion)
    enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case expiresIn
        case tokenType
    }
}

// MARK: - Token Response (for refresh)
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Refresh Token Request
struct RefreshTokenRequest: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - Logout Request
struct LogoutRequest: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - Logout Response
struct LogoutResponse: Codable {
    let success: Bool
    let message: String?
}
