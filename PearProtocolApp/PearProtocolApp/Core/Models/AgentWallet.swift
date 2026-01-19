import Foundation

// MARK: - Agent Wallet Model
/// Represents a Pear Protocol Agent Wallet for delegated trading
struct AgentWallet: Codable {
    let address: String
    let createdAt: Date
    let expiresAt: Date
    let isApproved: Bool
    let approvalSignature: String?
    
    // MARK: - Computed Properties
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var daysUntilExpiry: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiresAt)
        return max(0, components.day ?? 0)
    }
    
    var needsRefresh: Bool {
        daysUntilExpiry < Constants.AgentWallet.refreshThresholdDays
    }
    
    var formattedExpiry: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: expiresAt)
    }
    
    var truncatedAddress: String {
        address.truncatedAddress
    }
    
    var statusDescription: String {
        if isExpired {
            return "Expired"
        } else if needsRefresh {
            return "Expires in \(daysUntilExpiry) days"
        } else if !isApproved {
            return "Pending Approval"
        } else {
            return "Active"
        }
    }
    
    var isValid: Bool {
        !isExpired && isApproved
    }
}

// MARK: - Agent Wallet API Models
struct AgentWalletCreateRequest: Codable {
    let userWalletAddress: String
    let chainId: Int
    
    init(userWalletAddress: String, chainId: Int = Constants.Network.arbitrumChainId) {
        self.userWalletAddress = userWalletAddress
        self.chainId = chainId
    }
}

struct AgentWalletCreateResponse: Codable {
    let agentWalletAddress: String
    let messageToSign: String
    let expiresAt: Date?
    let nonce: String?
    let authToken: String?
    let clientToken: String?
    let token: String?
    
    // API returns "message" but we use "messageToSign" internally
    enum CodingKeys: String, CodingKey {
        case agentWalletAddress
        case messageToSign = "message"
        case expiresAt
        case nonce
        case authToken
        case clientToken
        case token
    }

    var resolvedAuthToken: String? {
        authToken ?? clientToken ?? token
    }
}

struct AgentWalletApproveRequest: Codable {
    let agentWalletAddress: String
    let signature: String
    let userWalletAddress: String
}

struct AgentWalletApproveResponse: Codable {
    let success: Bool
    let agentWallet: AgentWallet?
    let message: String?
    let authToken: String?
    let clientToken: String?
    let token: String?

    var resolvedAuthToken: String? {
        authToken ?? clientToken ?? token
    }
}

struct AgentWalletStatusResponse: Codable {
    let agentWallet: AgentWallet?
    let isActive: Bool
    let message: String?
    let authToken: String?
    let clientToken: String?
    let token: String?

    var resolvedAuthToken: String? {
        authToken ?? clientToken ?? token
    }
}

// MARK: - Builder Fee Approval
struct BuilderFeeApproval: Codable {
    let builderAddress: String
    let maxFeePercentage: Double
    let isApproved: Bool
    let approvedAt: Date?
    let transactionHash: String?
    
    var formattedMaxFee: String {
        "\(maxFeePercentage * 100)%"
    }
    
    static let pearBuilder = BuilderFeeApproval(
        builderAddress: "0x...", // Pear Protocol builder address
        maxFeePercentage: Constants.Trading.builderFeePercentage,
        isApproved: false,
        approvedAt: nil,
        transactionHash: nil
    )
}

// MARK: - Wallet Info
struct WalletInfo: Codable {
    let address: String
    let chainId: Int
    var ethBalance: Double
    var usdcBalance: Double
    
    var truncatedAddress: String {
        address.truncatedAddress
    }
    
    var formattedEthBalance: String {
        String(format: "%.4f ETH", ethBalance)
    }
    
    var formattedUsdcBalance: String {
        usdcBalance.asCurrency
    }
    
    var hasEnoughForGas: Bool {
        ethBalance > 0.001 // Minimum ETH for gas
    }
}
