import Foundation

// MARK: - App Constants
enum Constants {
    // MARK: - API Configuration
    enum API {
        static let baseURL = "https://api.pearprotocol.io"
        static let webSocketURL = "wss://api.pearprotocol.io/ws"
        
        // Endpoints
        static let agentWallet = "/agentWallet"
        static let activeAssets = "/activeAssets"
        static let tradeExecute = "/trade/execute"
        static let tradeClose = "/trade/close"
        static let positions = "/positions"
        static let tradeHistory = "/tradeHistory"
        static let marketData = "/marketData"
        
        // Timeouts
        static let requestTimeout: TimeInterval = 30
        static let resourceTimeout: TimeInterval = 60
        
        // Retry Configuration
        static let maxRetryAttempts = 3
        static let retryBaseDelay: TimeInterval = 1.0
    }
    
    // MARK: - Network
    enum Network {
        static let arbitrumChainId = 42161
        static let arbitrumRPCURL = "https://arb1.arbitrum.io/rpc"
        static let hyperliquidExplorerURL = "https://app.hyperliquid.xyz"
    }
    
    // MARK: - Agent Wallet
    enum AgentWallet {
        static let expiryDays = 180
        static let refreshThresholdDays = 7 // Refresh if less than 7 days left
    }
    
    // MARK: - WalletConnect
    enum WalletConnect {
        static let projectId = "" // Set in Config.plist
        static let appName = "Pear Protocol"
        static let appDescription = "Trade ideas, not tokens"
        static let appURL = "https://pearprotocol.io"
        static let appIconURL = "https://pearprotocol.io/icon.png"
    }
    
    // MARK: - Trading
    enum Trading {
        static let minPositionSize: Double = 10 // Minimum USDC
        static let maxBasketAssets = 10
        static let defaultLeverage = 1.0
        static let maxLeverage = 50.0
        static let builderFeePercentage = 0.001 // 0.1%
    }
    
    // MARK: - UI
    enum UI {
        static let animationDuration: Double = 0.3
        static let cornerRadius: CGFloat = 12
        static let cardPadding: CGFloat = 16
        static let hapticFeedbackEnabled = true
    }
    
    // MARK: - Storage Keys
    enum StorageKeys {
        static let agentWalletAddress = "pear.agentWallet.address"
        static let agentWalletExpiry = "pear.agentWallet.expiry"
        static let builderApprovalStatus = "pear.builder.approved"
        static let authToken = "pear.auth.token"
        static let connectedWalletAddress = "pear.wallet.address"
        static let hasCompletedOnboarding = "pear.onboarding.completed"
    }
}

// MARK: - Config Loader
enum ConfigLoader {
    static func loadAPIToken() -> String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let token = config["API_TOKEN"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    }
    
    static func loadWalletConnectProjectId() -> String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let projectId = config["WALLET_CONNECT_PROJECT_ID"] as? String,
              !projectId.isEmpty else {
            return nil
        }
        return projectId
    }
}
