import Foundation
import KeychainAccess

// MARK: - Keychain Service
/// Secure storage service for sensitive data using iOS Keychain
@MainActor
final class KeychainService: ObservableObject {
    static let shared = KeychainService()
    
    private let keychain: Keychain
    
    private init() {
        self.keychain = Keychain(service: "io.pearprotocol.app")
            .accessibility(.whenUnlockedThisDeviceOnly)
            .synchronizable(false)
    }
    
    // MARK: - Auth Token
    var authToken: String? {
        get {
            try? keychain.get(Constants.StorageKeys.authToken)
        }
        set {
            if let value = newValue {
                try? keychain.set(value, key: Constants.StorageKeys.authToken)
            } else {
                try? keychain.remove(Constants.StorageKeys.authToken)
            }
        }
    }
    
    var refreshToken: String? {
        get {
            try? keychain.get(Constants.StorageKeys.refreshToken)
        }
        set {
            if let value = newValue {
                try? keychain.set(value, key: Constants.StorageKeys.refreshToken)
            } else {
                try? keychain.remove(Constants.StorageKeys.refreshToken)
            }
        }
    }
    
    var tokenExpiresAt: Date? {
        get {
            guard let timestamp = try? keychain.get(Constants.StorageKeys.tokenExpiresAt),
                  let interval = Double(timestamp) else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let value = newValue {
                try? keychain.set(String(value.timeIntervalSince1970), key: Constants.StorageKeys.tokenExpiresAt)
            } else {
                try? keychain.remove(Constants.StorageKeys.tokenExpiresAt)
            }
        }
    }
    
    // MARK: - Agent Wallet
    var agentWalletAddress: String? {
        get {
            try? keychain.get(Constants.StorageKeys.agentWalletAddress)
        }
        set {
            if let value = newValue {
                try? keychain.set(value, key: Constants.StorageKeys.agentWalletAddress)
            } else {
                try? keychain.remove(Constants.StorageKeys.agentWalletAddress)
            }
        }
    }
    
    var agentWalletExpiry: Date? {
        get {
            guard let timestamp = try? keychain.get(Constants.StorageKeys.agentWalletExpiry),
                  let interval = Double(timestamp) else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let value = newValue {
                try? keychain.set(String(value.timeIntervalSince1970), key: Constants.StorageKeys.agentWalletExpiry)
            } else {
                try? keychain.remove(Constants.StorageKeys.agentWalletExpiry)
            }
        }
    }
    
    // MARK: - Pending Agent Wallet (pre-approval state)
    var pendingAgentWalletAddress: String? {
        get {
            try? keychain.get(Constants.StorageKeys.pendingAgentWalletAddress)
        }
        set {
            if let value = newValue {
                try? keychain.set(value, key: Constants.StorageKeys.pendingAgentWalletAddress)
            } else {
                try? keychain.remove(Constants.StorageKeys.pendingAgentWalletAddress)
            }
        }
    }
    
    var pendingAgentWalletExpiry: Date? {
        get {
            guard let timestamp = try? keychain.get(Constants.StorageKeys.pendingAgentWalletExpiry),
                  let interval = Double(timestamp) else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let value = newValue {
                try? keychain.set(String(value.timeIntervalSince1970), key: Constants.StorageKeys.pendingAgentWalletExpiry)
            } else {
                try? keychain.remove(Constants.StorageKeys.pendingAgentWalletExpiry)
            }
        }
    }
    
    var pendingAgentWalletMessage: String? {
        get {
            try? keychain.get(Constants.StorageKeys.pendingAgentWalletMessage)
        }
        set {
            if let value = newValue {
                try? keychain.set(value, key: Constants.StorageKeys.pendingAgentWalletMessage)
            } else {
                try? keychain.remove(Constants.StorageKeys.pendingAgentWalletMessage)
            }
        }
    }
    
    var pendingAgentUserWalletAddress: String? {
        get {
            try? keychain.get(Constants.StorageKeys.pendingAgentUserWalletAddress)
        }
        set {
            if let value = newValue {
                try? keychain.set(value, key: Constants.StorageKeys.pendingAgentUserWalletAddress)
            } else {
                try? keychain.remove(Constants.StorageKeys.pendingAgentUserWalletAddress)
            }
        }
    }
    
    // MARK: - Connected Wallet
    var connectedWalletAddress: String? {
        get {
            try? keychain.get(Constants.StorageKeys.connectedWalletAddress)
        }
        set {
            if let value = newValue {
                try? keychain.set(value, key: Constants.StorageKeys.connectedWalletAddress)
            } else {
                try? keychain.remove(Constants.StorageKeys.connectedWalletAddress)
            }
        }
    }
    
    // MARK: - Builder Approval
    var isBuilderApproved: Bool {
        get {
            (try? keychain.get(Constants.StorageKeys.builderApprovalStatus)) == "true"
        }
        set {
            try? keychain.set(newValue ? "true" : "false", key: Constants.StorageKeys.builderApprovalStatus)
        }
    }
    
    // MARK: - Onboarding Status
    var hasCompletedOnboarding: Bool {
        get {
            (try? keychain.get(Constants.StorageKeys.hasCompletedOnboarding)) == "true"
        }
        set {
            try? keychain.set(newValue ? "true" : "false", key: Constants.StorageKeys.hasCompletedOnboarding)
        }
    }
    
    // MARK: - Generic Storage
    func set(_ value: String, forKey key: String) {
        try? keychain.set(value, key: key)
    }
    
    func get(forKey key: String) -> String? {
        try? keychain.get(key)
    }
    
    // MARK: - Clear All
    func clearAll() {
        try? keychain.removeAll()
    }
    
    // MARK: - Validation
    func validateStoredData() -> StoredDataStatus {
        var status = StoredDataStatus()
        
        status.hasAuthToken = authToken != nil
        status.hasAgentWallet = agentWalletAddress != nil
        status.hasConnectedWallet = connectedWalletAddress != nil
        status.isBuilderApproved = isBuilderApproved
        
        if let expiry = agentWalletExpiry {
            status.isAgentWalletExpired = Date() > expiry
            status.agentWalletDaysRemaining = Calendar.current.dateComponents(
                [.day],
                from: Date(),
                to: expiry
            ).day ?? 0
        }
        
        return status
    }
}

// MARK: - Stored Data Status
struct StoredDataStatus {
    var hasAuthToken: Bool = false
    var hasAgentWallet: Bool = false
    var hasConnectedWallet: Bool = false
    var isBuilderApproved: Bool = false
    var isAgentWalletExpired: Bool = false
    var agentWalletDaysRemaining: Int = 0
    
    var isFullyConfigured: Bool {
        hasAuthToken &&
        hasAgentWallet &&
        hasConnectedWallet &&
        isBuilderApproved &&
        !isAgentWalletExpired
    }
    
    var needsAgentWalletRefresh: Bool {
        agentWalletDaysRemaining < Constants.AgentWallet.refreshThresholdDays
    }
}

// MARK: - Auth Service
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private var refreshTimer: Timer?
    private let tokenRefreshThreshold: TimeInterval = 60 // Refresh 1 minute before expiry

    private init() {
        startTokenExpirationMonitoring()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }

    func bootstrap() {
        // #region agent log
        let keychainToken = KeychainService.shared.authToken
        let configToken = ConfigLoader.loadAPIToken()
        let finalToken = keychainToken ?? configToken
        DebugLogger.log(
            location: "KeychainService.swift:197",
            message: "AuthService.bootstrap called",
            data: [
                "hasKeychainToken": keychainToken != nil,
                "hasConfigToken": configToken != nil,
                "hasFinalToken": finalToken != nil,
                "keychainTokenLength": keychainToken?.count ?? 0,
                "configTokenLength": configToken?.count ?? 0
            ],
            hypothesisId: "B"
        )
        // #endregion
        
        let token = finalToken
        // Bootstrap is called synchronously on init, so we can't await
        // The token will be applied asynchronously, but since it's on app startup
        // and API calls happen later, this should be fine
        Task { @MainActor in
            await applyToken(token)
        }
    }

    func updateAuthToken(_ token: String?, refreshToken: String? = nil, expiresIn: Int? = nil) async {
        if let token, !token.isEmpty {
            KeychainService.shared.authToken = token
            
            if let refreshToken {
                KeychainService.shared.refreshToken = refreshToken
            }
            
            if let expiresIn {
                let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
                KeychainService.shared.tokenExpiresAt = expiresAt
            }
            
            await applyToken(token)
            startTokenExpirationMonitoring()
        } else {
            KeychainService.shared.authToken = nil
            KeychainService.shared.refreshToken = nil
            KeychainService.shared.tokenExpiresAt = nil
            await applyToken(nil)
            stopTokenExpirationMonitoring()
        }
    }

    func clearAuthToken() async {
        await updateAuthToken(nil)
    }
    
    // MARK: - Token Refresh
    func refreshAccessToken() async throws {
        guard let refreshToken = KeychainService.shared.refreshToken else {
            throw AuthError.noRefreshToken
        }
        
        do {
            let response = try await PearAPIService.shared.refreshToken(refreshToken: refreshToken)
            await updateAuthToken(
                response.accessToken,
                refreshToken: response.refreshToken ?? refreshToken,
                expiresIn: response.expiresIn
            )
        } catch {
            // If refresh fails, clear tokens and require re-authentication
            await clearAuthToken()
            throw AuthError.refreshFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Token Expiration Monitoring
    private func startTokenExpirationMonitoring() {
        stopTokenExpirationMonitoring()
        
        guard let expiresAt = KeychainService.shared.tokenExpiresAt else { return }
        
        let timeUntilRefresh = expiresAt.timeIntervalSinceNow - tokenRefreshThreshold
        
        guard timeUntilRefresh > 0 else {
            // Token is already expired or about to expire, refresh immediately
            Task {
                try? await refreshAccessToken()
            }
            return
        }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: timeUntilRefresh, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.refreshAccessToken()
            }
        }
    }
    
    private func stopTokenExpirationMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    var isTokenExpired: Bool {
        guard let expiresAt = KeychainService.shared.tokenExpiresAt else { return true }
        return Date() >= expiresAt
    }
    
    var timeUntilExpiry: TimeInterval? {
        guard let expiresAt = KeychainService.shared.tokenExpiresAt else { return nil }
        return expiresAt.timeIntervalSinceNow
    }

    private func applyToken(_ token: String?) async {
        // #region agent log
        DebugLogger.log(
            location: "KeychainService.swift:288",
            message: "applyToken called",
            data: [
                "hasToken": token != nil,
                "tokenLength": token?.count ?? 0,
                "tokenPreview": token != nil ? String(token!.prefix(20)) + "..." : "nil"
            ],
            hypothesisId: "B,C"
        )
        // #endregion
        
        // Apply token to PearAPIService (actor) - await to ensure it's set before any API calls
        await PearAPIService.shared.setAuthToken(token)
        
        // #region agent log
        DebugLogger.log(
            location: "KeychainService.swift:295",
            message: "setAuthToken completed in PearAPIService",
            data: ["hasToken": token != nil],
            hypothesisId: "C"
        )
        // #endregion
        
        // Apply token to WebSocketService and ensure connection is established
        // This will reconnect if already connected, or connect if disconnected
        WebSocketService.shared.setAuthToken(token)
        
        // Ensure WebSocket is connected after authentication
        // setAuthToken() handles reconnection, but we also want to ensure connection
        // if it hasn't been established yet (e.g., on first authentication)
        if token != nil && !WebSocketService.shared.isConnected {
            print("🔵 [DEBUG] Auth token applied - ensuring WebSocket connection")
            WebSocketService.shared.connect()
        }
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case noRefreshToken
    case refreshFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available. Please re-authenticate."
        case .refreshFailed(let message):
            return "Token refresh failed: \(message)"
        }
    }
}
