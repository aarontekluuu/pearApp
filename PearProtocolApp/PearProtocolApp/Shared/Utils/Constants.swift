import Foundation

// MARK: - App Constants
enum Constants {
    // MARK: - API Configuration
    enum API {
        // Production endpoint for Pear Protocol Hyperliquid V2 (mainnet)
        // This connects to Hyperliquid mainnet via Pear Protocol's abstraction layer
        // Hyperliquid mainnet API: https://api.hyperliquid.xyz
        static let baseURL = "https://hl-v2.pearprotocol.io"
        static let webSocketURL = "wss://hl-v2.pearprotocol.io/ws"
        
        // Endpoints (matching Pear Protocol API v2)
        static let agentWallet = "/agentWallet"  // Note: camelCase per API spec
        static let activeAssets = "/markets/active"  // GET /markets/active - returns ActiveAssetsResponse
        static let tradeExecute = "/positions"           // POST to create position
        static let tradeClose = "/positions"             // POST to /positions/{id}/close
        static let positions = "/positions"
        static let tradeHistory = "/positions/history"
        static let marketData = "/market-data"
        static let authEIP712Message = "/auth/eip712-message"
        static let authLogin = "/auth/login"
        static let authRefresh = "/auth/refresh"
        static let authLogout = "/auth/logout"
        static let health = "/health"
        static let accounts = "/accounts"
        static let notifications = "/notifications"
        static let watchlist = "/watchlist"
        static let portfolio = "/portfolio"
        static let orders = "/orders"
        
        // Timeouts
        static let requestTimeout: TimeInterval = 30
        static let resourceTimeout: TimeInterval = 60
        
        // Retry Configuration
        static let maxRetryAttempts = 3
        static let retryBaseDelay: TimeInterval = 1.0
    }
    
    // MARK: - Network
    enum Network {
        // Arbitrum One mainnet chain ID (production)
        static let arbitrumChainId = 42161
        // Arbitrum One mainnet RPC endpoint (production)
        static let arbitrumRPCURL = "https://arb1.arbitrum.io/rpc"
        // Hyperliquid mainnet explorer/app URL
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
    
    // MARK: - Contracts
    enum Contracts {
        static var builderContractAddress: String {
            ConfigLoader.loadBuilderContractAddress() ?? "0x0000000000000000000000000000000000000000"
        }
    }
    
    // MARK: - UI (Design System Tokens)
    enum UI {
        // Animation
        static let animationDuration: Double = 0.3
        static let animationSpring: Double = 0.5
        
        // Corner Radius
        static let cornerRadius: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16
        
        // Spacing Grid (8pt base)
        static let spacingXS: CGFloat = 4
        static let spacingSM: CGFloat = 8
        static let spacingMD: CGFloat = 16
        static let spacingLG: CGFloat = 24
        static let spacingXL: CGFloat = 32
        
        // Component Sizing
        static let buttonHeight: CGFloat = 48
        static let buttonHeightLarge: CGFloat = 56
        static let iconSize: CGFloat = 24
        static let iconSizeLarge: CGFloat = 44
        
        // Layout
        static let cardPadding: CGFloat = 16
        static let safeAreaMargin: CGFloat = 16
    }
    
    // MARK: - Debug
    enum Debug {
        // Set to true to enable debug bypass for wallet connection and agent creation
        // This allows you to skip onboarding for product demos/videos
        static let enableBypass = true // TODO: Set to false before production release
    }
    
    // MARK: - Storage Keys
    enum StorageKeys {
        static let agentWalletAddress = "pear.agentWallet.address"
        static let agentWalletExpiry = "pear.agentWallet.expiry"
        static let pendingAgentWalletAddress = "pear.agentWallet.pendingAddress"
        static let pendingAgentWalletExpiry = "pear.agentWallet.pendingExpiry"
        static let pendingAgentWalletMessage = "pear.agentWallet.pendingMessage"
        static let pendingAgentUserWalletAddress = "pear.agentWallet.pendingUserAddress"
        static let builderApprovalStatus = "pear.builder.approved"
        static let authToken = "pear.auth.token"
        static let refreshToken = "pear.auth.refreshToken"
        static let tokenExpiresAt = "pear.auth.tokenExpiresAt"
        static let connectedWalletAddress = "pear.wallet.address"
        static let hasCompletedOnboarding = "pear.onboarding.completed"
    }
    
    // MARK: - Device Detection
    enum Device {
        static var isSimulator: Bool {
            #if targetEnvironment(simulator)
            return true
            #else
            return false
            #endif
        }
    }
}

// MARK: - Config Loader
enum ConfigLoader {
    enum ConfigError: LocalizedError {
        case configFileNotFound
        case missingKey(String)
        case invalidValue(String)
        
        var errorDescription: String? {
            switch self {
            case .configFileNotFound:
                return "Config.plist file not found. Please ensure it's included in the app bundle."
            case .missingKey(let key):
                return "Missing required configuration: \(key). Please check Config.plist."
            case .invalidValue(let key):
                return "Invalid or empty value for: \(key). Please check Config.plist."
            }
        }
    }
    
    private static func loadConfig() -> NSDictionary? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) else {
            print("⚠️ Config.plist not found in bundle")
            return nil
        }
        return config
    }
    
    static func loadAPIToken() -> String? {
        guard let config = loadConfig(),
              let token = config["API_TOKEN"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    }
    
    static func loadWalletConnectProjectId() -> String? {
        guard let config = loadConfig() else {
            print("⚠️ \(ConfigError.configFileNotFound.localizedDescription)")
            return nil
        }
        
        guard let projectId = config["WALLET_CONNECT_PROJECT_ID"] as? String,
              !projectId.isEmpty else {
            print("⚠️ \(ConfigError.invalidValue("WALLET_CONNECT_PROJECT_ID").localizedDescription)")
            return nil
        }
        return projectId
    }
    
    static func loadClientID() -> String? {
        guard let config = loadConfig() else {
            print("⚠️ \(ConfigError.configFileNotFound.localizedDescription)")
            return nil
        }
        
        guard let clientId = config["CLIENT_ID"] as? String,
              !clientId.isEmpty else {
            print("⚠️ \(ConfigError.invalidValue("CLIENT_ID").localizedDescription)")
            return nil
        }
        return clientId
    }
    
    static func loadBuilderContractAddress() -> String? {
        guard let config = loadConfig() else {
            print("⚠️ \(ConfigError.configFileNotFound.localizedDescription)")
            return nil
        }
        
        guard let address = config["BUILDER_CONTRACT_ADDRESS"] as? String,
              !address.isEmpty else {
            print("⚠️ \(ConfigError.invalidValue("BUILDER_CONTRACT_ADDRESS").localizedDescription)")
            return nil
        }
        return address
    }
    
    static func validateRequiredConfig() -> Bool {
        guard loadConfig() != nil else {
            print("❌ Config validation failed: Config.plist not found")
            return false
        }
        
        var isValid = true
        
        if loadWalletConnectProjectId() == nil {
            print("❌ Config validation failed: WALLET_CONNECT_PROJECT_ID is required")
            isValid = false
        }
        
        if loadClientID() == nil {
            print("❌ Config validation failed: CLIENT_ID is required")
            isValid = false
        }
        
        if loadBuilderContractAddress() == nil {
            print("⚠️  Config validation warning: BUILDER_CONTRACT_ADDRESS not set")
        }
        
        return isValid
    }
}

// MARK: - Debug Logger (for instrumentation)
// #region agent log
enum DebugLogger {
    private static let logPath = "/Users/aaronteklu/pearProtocolApp/.cursor/debug.log"
    
    static func log(location: String, message: String, data: [String: Any] = [:], hypothesisId: String = "") {
        let entry: [String: Any] = [
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "location": location,
            "message": message,
            "data": data,
            "hypothesisId": hypothesisId,
            "sessionId": "debug-session"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: entry),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let line = jsonString + "\n"
        
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
    }
}
// #endregion
