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
    let expiresAt: Date
    let nonce: String
    let authToken: String?
    let clientToken: String?
    let token: String?

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

// MARK: - Sample Data
extension AgentWallet {
    static let sample = AgentWallet(
        address: "0x1234567890abcdef1234567890abcdef12345678",
        createdAt: Date().addingTimeInterval(-86400 * 30),
        expiresAt: Date().addingTimeInterval(86400 * 150),
        isApproved: true,
        approvalSignature: "0xsignature..."
    )
    
    static let expiringSoon = AgentWallet(
        address: "0xabcdef1234567890abcdef1234567890abcdef12",
        createdAt: Date().addingTimeInterval(-86400 * 175),
        expiresAt: Date().addingTimeInterval(86400 * 5),
        isApproved: true,
        approvalSignature: "0xsignature..."
    )
    
    static let pendingApproval = AgentWallet(
        address: "0xfedcba0987654321fedcba0987654321fedcba09",
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(86400 * 180),
        isApproved: false,
        approvalSignature: nil
    )
}

extension WalletInfo {
    static let sample = WalletInfo(
        address: "0x742d35Cc6634C0532925a3b844Bc9e7595f5aE31",
        chainId: Constants.Network.arbitrumChainId,
        ethBalance: 0.125,
        usdcBalance: 2500.00
    )
}
