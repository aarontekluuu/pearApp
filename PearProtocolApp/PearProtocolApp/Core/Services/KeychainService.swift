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
