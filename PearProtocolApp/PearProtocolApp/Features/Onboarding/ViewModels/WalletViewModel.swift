import Foundation
import SwiftUI
import Combine
import WalletConnectSign

// MARK: - Wallet ViewModel
@MainActor
final class WalletViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var showError: Bool = false
    @Published var selectedWallet: WalletType?
    @Published var connectionStage: ConnectionStage = .idle
    @Published var installedWallets: [WalletType] = []
    
    // Agent Wallet State
    @Published var agentWalletAddress: String?
    @Published var messageToSign: String?
    
    // Track if wallet was connected during this onboarding session (not from restored session)
    @Published var hasConnectedInThisSession: Bool = false {
        didSet {
            DebugLogger.log(
                location: "WalletViewModel.swift:23",
                message: "hasConnectedInThisSession changed",
                data: [
                    "oldValue": oldValue,
                    "newValue": hasConnectedInThisSession,
                    "currentStep": currentStep.rawValue,
                    "isWalletConnected": isWalletConnected
                ],
                hypothesisId: "E"
            )
        }
    }
    
    // MARK: - Dependencies
    private let walletService = WalletService.shared
    private let walletRepository = WalletRepository.shared
    private let keychainService = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // AppState reference for bypass
    var appState: AppState?
    
    // MARK: - Computed Properties
    var isWalletConnected: Bool {
        walletService.isConnected
    }
    
    var connectedAddress: String? {
        walletService.connectedAddress
    }
    
    var truncatedAddress: String {
        walletService.connectedAddress?.truncatedAddress ?? ""
    }
    
    var isAgentWalletApproved: Bool {
        walletRepository.agentWallet?.isApproved == true
    }
    
    var isBuilderApproved: Bool {
        walletRepository.isBuilderApproved
    }
    
    var isFullyOnboarded: Bool {
        isWalletConnected && isAgentWalletApproved && isBuilderApproved
    }
    
    var pairingURI: String? {
        walletService.currentPairingURI
    }
    
    // MARK: - Init
    init() {
        setupBindings()
        checkInitialState()
    }
    
    private func setupBindings() {
        // Only track connection stage for UI updates
        // User must explicitly proceed through each step - no auto-advance
        walletService.$connectionStage
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStage)
    }
    
    private func checkInitialState() {
        // Reset session tracking - connection must happen during this onboarding flow
        hasConnectedInThisSession = false
        
        DebugLogger.log(
            location: "WalletViewModel.swift:71",
            message: "checkInitialState - wallet state",
            data: [
                "isWalletConnected": isWalletConnected,
                "connectedAddress": connectedAddress ?? "nil",
                "hasConnectedInThisSession": hasConnectedInThisSession,
                "isAgentWalletApproved": isAgentWalletApproved,
                "isBuilderApproved": isBuilderApproved
            ],
            hypothesisId: "A"
        )
        
        // Always start at welcome on fresh app launch
        // User must explicitly proceed through onboarding even if they have stored sessions
        // This ensures wallet connection is verified and user is aware of the state
        currentStep = .welcome
        
        print("🔵 [DEBUG] WalletViewModel checkInitialState - starting at welcome")
        print("🔵 [DEBUG] Stored state - isWalletConnected: \(isWalletConnected), isAgentWalletApproved: \(isAgentWalletApproved), isBuilderApproved: \(isBuilderApproved)")
    }
    
    // MARK: - Debug Bypass
    /// Bypasses entire onboarding flow for development/demo purposes
    /// Sets fake wallet, agent wallet, and builder approval
    func bypassOnboarding() {
        guard Constants.Debug.enableBypass else {
            print("⚠️ [DEBUG] Bypass disabled - not bypassing onboarding")
            return
        }
        
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] 🚨 DEBUG BYPASS: Full Onboarding")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] ⚠️ WARNING: This is a debug bypass")
        print("🔵 [DEBUG] ⚠️ DO NOT USE IN PRODUCTION")
        print("🔵 [DEBUG] ========================================")
        
        // 1. Bypass wallet connection
        walletService.bypassConnection()
        hasConnectedInThisSession = true
        print("🔵 [DEBUG] ✅ Wallet connection bypassed")
        
        // 2. Bypass agent wallet creation
        let fakeAgentAddress = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
        agentWalletAddress = fakeAgentAddress
        keychainService.pendingAgentWalletAddress = fakeAgentAddress
        keychainService.pendingAgentUserWalletAddress = walletService.connectedAddress
        
        // Store fake agent wallet metadata in keychain for debug
        let now = Date()
        let expires = now.addingTimeInterval(180 * 24 * 60 * 60) // 180 days
        keychainService.agentWalletAddress = fakeAgentAddress
        keychainService.agentWalletExpiry = expires
        print("🔵 [DEBUG] ✅ Agent wallet bypassed: \(fakeAgentAddress)")
        
        // 3. Bypass builder approval
        keychainService.isBuilderApproved = true
        print("🔵 [DEBUG] ✅ Builder approval bypassed")
        
        // 4. Update AppState
        appState?.bypassOnboardingState()
        
        print("🔵 [DEBUG] ✅ Full onboarding bypass complete")
        print("🔵 [DEBUG] ========================================")
    }
    
    // MARK: - Skip Actions (Debug Bypass)
    /// Skips wallet connection step
    func skipWalletConnection() async {
        guard Constants.Debug.enableBypass else { return }
        
        print("🔵 [DEBUG] 🚨 SKIP: Wallet Connection")
        walletService.bypassConnection()
        hasConnectedInThisSession = true
        
        // Set a fake auth token early so API calls work
        // This ensures market data can be fetched even when skipping onboarding
        // CRITICAL: Wait for token to be set before proceeding
        await AuthService.shared.updateAuthToken("fake_auth_token_for_debug")
        print("🔵 [DEBUG] ✅ Auth token set for API calls")
        
        print("🔵 [DEBUG] ✅ Wallet connection skipped")
    }
    
    /// Skips agent wallet creation step
    func skipAgentWalletCreation() {
        guard Constants.Debug.enableBypass else { return }
        
        print("🔵 [DEBUG] 🚨 SKIP: Agent Wallet Creation")
        let fakeAgentAddress = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
        agentWalletAddress = fakeAgentAddress
        keychainService.pendingAgentWalletAddress = fakeAgentAddress
        keychainService.pendingAgentUserWalletAddress = walletService.connectedAddress
        
        let now = Date()
        let expires = now.addingTimeInterval(180 * 24 * 60 * 60) // 180 days
        keychainService.agentWalletAddress = fakeAgentAddress
        keychainService.agentWalletExpiry = expires
        print("🔵 [DEBUG] ✅ Agent wallet creation skipped")
    }
    
    /// Skips agent approval signing step
    func skipAgentApproval() {
        guard Constants.Debug.enableBypass else { return }
        
        print("🔵 [DEBUG] 🚨 SKIP: Agent Approval Signing")
        
        // Set fake auth token using AuthService to ensure it's applied to API service
        // This is critical - without this, API calls will fail
        Task {
            await AuthService.shared.updateAuthToken("fake_auth_token_for_debug")
            print("🔵 [DEBUG] ✅ Auth token set in API service")
        }
        
        // Ensure agent wallet is in keychain (should already be there from skipAgentWalletCreation)
        if let agentAddress = agentWalletAddress {
            // Ensure expiry is set (should already be set from skipAgentWalletCreation)
            if keychainService.agentWalletExpiry == nil {
                let expires = Date().addingTimeInterval(180 * 24 * 60 * 60) // 180 days
                keychainService.agentWalletExpiry = expires
            }
            
            // Clear pending state
            keychainService.pendingAgentWalletAddress = nil
            keychainService.pendingAgentUserWalletAddress = nil
            keychainService.pendingAgentWalletMessage = nil
            keychainService.pendingAgentWalletExpiry = nil
        }
        
        // Reload agent wallet from keychain to ensure it's marked as approved
        walletRepository.reloadAgentWalletFromKeychain()
        
        print("🔵 [DEBUG] ✅ Agent approval skipped - proceeding to builder approval")
        
        // Advance to builder approval step
        currentStep = .approveBuilder
    }
    
    /// Skips builder fee approval step
    func skipBuilderApproval() {
        guard Constants.Debug.enableBypass else { return }
        
        print("🔵 [DEBUG] 🚨 SKIP: Builder Fee Approval")
        
        // Set builder approval status
        walletRepository.setBuilderApproved(true)
        keychainService.isBuilderApproved = true
        
        // Store fake transaction hash for consistency
        keychainService.set("fake_tx_hash_for_debug", forKey: "pear.builder.txHash")
        
        print("🔵 [DEBUG] ✅ Builder approval skipped - onboarding complete")
        
        // Advance to complete step
        currentStep = .complete
    }
    
    // MARK: - Actions
    func startOnboarding() {
        currentStep = .connectWallet
    }
    
    func connectWallet() async {
        let wasConnectedBefore = isWalletConnected
        
        DebugLogger.log(
            location: "WalletViewModel.swift:111",
            message: "connectWallet entry",
            data: [
                "currentStep": currentStep.rawValue,
                "isWalletConnectedBefore": wasConnectedBefore,
                "hasConnectedInThisSession": hasConnectedInThisSession,
                "selectedWallet": selectedWallet?.displayName ?? "nil"
            ],
            hypothesisId: "B"
        )
        
        isLoading = true
        error = nil
        
        do {
            _ = try await walletService.connect(walletType: selectedWallet)
            
            // If user explicitly initiated connection during onboarding and it succeeded,
            // mark as connected in this session so they can proceed
            // This allows users to reconnect even if there was a restored session
            hasConnectedInThisSession = true
            
            DebugLogger.log(
                location: "WalletViewModel.swift:140",
                message: "connectWallet success - marked hasConnectedInThisSession",
                data: [
                    "wasConnectedBefore": wasConnectedBefore,
                    "isWalletConnectedAfter": isWalletConnected,
                    "connectedAddress": connectedAddress ?? "nil",
                    "hasConnectedInThisSession": hasConnectedInThisSession
                ],
                hypothesisId: "B"
            )
            
            // Connection successful - stay on this step
            // User must explicitly tap "Continue" to proceed
            // Authentication will happen later during agent approval
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func proceedFromConnection() async {
        DebugLogger.log(
            location: "WalletViewModel.swift:176",
            message: "proceedFromConnection called",
            data: [
                "currentStep": currentStep.rawValue,
                "isWalletConnected": isWalletConnected,
                "hasConnectedInThisSession": hasConnectedInThisSession,
                "connectedAddress": connectedAddress ?? "nil"
            ],
            hypothesisId: "D"
        )
        
        // Allow proceeding if wallet is connected OR if we're in debug bypass mode
        // (skip sets hasConnectedInThisSession but wallet might not be "connected" yet)
        guard isWalletConnected || (Constants.Debug.enableBypass && hasConnectedInThisSession) else {
            error = "Wallet not connected"
            showError = true
            return
        }
        
        // Don't authenticate here - wait until user actually taps "Create Agent Wallet"
        // This ensures the EIP-712 message timestamp is fresh when we need it
        currentStep = .createAgentWallet
        
        DebugLogger.log(
            location: "WalletViewModel.swift:195",
            message: "proceedFromConnection advanced step",
            data: ["newStep": currentStep.rawValue],
            hypothesisId: "D"
        )
    }
    
    // MARK: - Authentication
    func authenticate() async throws {
        guard let address = connectedAddress,
              let clientId = ConfigLoader.loadClientID() else {
            // #region agent log
            print("🟡 [HYPO-A,E] authenticate guard failed - hasAddress: \(connectedAddress != nil), hasClientId: \(ConfigLoader.loadClientID() != nil)")
            // #endregion
            print("🔵 [DEBUG] Cannot authenticate: missing address or clientId")
            throw WalletError.connectionFailed("Missing address or client ID")
        }
        
        // Retry authentication up to 2 times if timestamp error occurs
        let maxRetries = 2
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                // Step 1: Get EIP-712 message RIGHT BEFORE signing to ensure fresh timestamp
                // This prevents "Invalid timestamp" errors that occur when the message
                // is fetched too early and expires before the user signs it
                if attempt > 0 {
                    print("🔵 [DEBUG] Retry \(attempt): Fetching fresh EIP-712 message for authentication...")
                } else {
                    print("🔵 [DEBUG] Fetching fresh EIP-712 message for authentication...")
                }
                var eip712Response = try await PearAPIService.shared.getEIP712Message(address: address, clientId: clientId)
                
                // #region agent log
                print("🟡 [HYPO-D] EIP-712 message received - primaryType: \(eip712Response.primaryType), messageKeys: \(eip712Response.message.keys)")
                // #endregion
                
                // Validate timestamp freshness - ensure we have a recent message
                // The API validates timestamps strictly, so we need a message that's very recent
                if let initialTimestamp = eip712Response.message["timestamp"]?.value as? Int {
                    let timestampDate = Date(timeIntervalSince1970: TimeInterval(initialTimestamp))
                    let currentDate = Date()
                    let timeDifference = timestampDate.timeIntervalSince(currentDate)
                    
                    // #region agent log
                    print("🟡 [HYPO-D] Initial message timestamp: \(initialTimestamp) (\(timestampDate))")
                    print("🟡 [HYPO-D] Current time: \(currentDate)")
                    print("🟡 [HYPO-D] Time difference: \(timeDifference) seconds (\(timeDifference > 0 ? "future" : "past"))")
                    // #endregion
                    
                    // If timestamp is more than 0.1 seconds in the past, get a fresh message
                    // We want the freshest possible timestamp to minimize validation issues
                    // The API is very strict about timestamp freshness (likely <2 seconds)
                    if timeDifference < -0.1 {
                        print("⚠️ [DEBUG] Timestamp is \(abs(timeDifference))s in the past - fetching fresh message...")
                        // No delay - get message immediately to minimize age
                        eip712Response = try await PearAPIService.shared.getEIP712Message(address: address, clientId: clientId)
                        
                        // Log the new timestamp
                        if let newTimestamp = eip712Response.message["timestamp"]?.value as? Int {
                            let newTimestampDate = Date(timeIntervalSince1970: TimeInterval(newTimestamp))
                            let newTimeDifference = newTimestampDate.timeIntervalSince(Date())
                            print("🟡 [HYPO-D] Fresh message timestamp: \(newTimestamp) (\(newTimestampDate)), difference: \(newTimeDifference)s")
                            
                            // If still stale, one more refresh (but don't delay)
                            if newTimeDifference < -0.1 {
                                print("⚠️ [DEBUG] Fresh timestamp still stale - one more refresh...")
                                eip712Response = try await PearAPIService.shared.getEIP712Message(address: address, clientId: clientId)
                                
                                // Final check
                                if let finalTimestamp = eip712Response.message["timestamp"]?.value as? Int {
                                    let finalTimestampDate = Date(timeIntervalSince1970: TimeInterval(finalTimestamp))
                                    let finalTimeDifference = finalTimestampDate.timeIntervalSince(Date())
                                    print("🟡 [HYPO-D] Final message timestamp: \(finalTimestamp) (\(finalTimestampDate)), difference: \(finalTimeDifference)s")
                                }
                            }
                        }
                    }
                }
                
                // Step 2: Extract timestamp from the EXACT message that will be signed
                // CRITICAL: We must extract and preserve the EXACT timestamp value
                // The API will reconstruct the message with this timestamp and verify the signature
                // Any mismatch will cause authentication to fail
                
                guard let timestampValue = eip712Response.message["timestamp"]?.value else {
                    print("🔵 [DEBUG] ❌ No timestamp found in EIP-712 message")
                    throw WalletError.connectionFailed("Invalid EIP-712 message: missing timestamp")
                }
                
                // Extract timestamp ensuring it's an Int (not String, not Double, etc.)
                // The API expects an Int timestamp that matches exactly what was signed
                let timestamp: Int
                if let intValue = timestampValue as? Int {
                    timestamp = intValue
                } else if let doubleValue = timestampValue as? Double {
                    // Handle case where API returns Double (shouldn't happen but be safe)
                    timestamp = Int(doubleValue)
                    print("🔵 [DEBUG] ⚠️ Timestamp was Double, converted to Int: \(timestamp)")
                } else if let stringValue = timestampValue as? String, let intFromString = Int(stringValue) {
                    // Handle case where API returns String (shouldn't happen but be safe)
                    timestamp = intFromString
                    print("🔵 [DEBUG] ⚠️ Timestamp was String, converted to Int: \(timestamp)")
                } else {
                    print("🔵 [DEBUG] ❌ Timestamp is not a valid Int type: \(type(of: timestampValue)), value: \(timestampValue)")
                    throw WalletError.connectionFailed("Invalid EIP-712 message: timestamp is not an integer")
                }
                
                // CRITICAL: Store the timestamp IMMEDIATELY after extraction
                // This ensures we use the exact same value for both signing and API call
                let extractedTimestamp = timestamp
                print("🔵 [DEBUG] ✅ TIMESTAMP EXTRACTED AND LOCKED: \(extractedTimestamp)")
                print("🔵 [DEBUG] ✅ This exact value will be used for:")
                print("🔵 [DEBUG]    1. EIP-712 message signing (must match)")
                print("🔵 [DEBUG]    2. Login API request (must match)")
                
                // Validate timestamp is reasonable (not too old, not in future)
                let timestampDate = Date(timeIntervalSince1970: TimeInterval(extractedTimestamp))
                let currentDate = Date()
                let age = currentDate.timeIntervalSince(timestampDate)
                
                print("🔵 [DEBUG] ========================================")
                print("🔵 [DEBUG] 📋 TIMESTAMP VERIFICATION SUMMARY")
                print("🔵 [DEBUG] ========================================")
                print("🔵 [DEBUG] ✅ LOCKED TIMESTAMP: \(extractedTimestamp)")
                print("🔵 [DEBUG] Timestamp date: \(timestampDate)")
                print("🔵 [DEBUG] Current date: \(currentDate)")
                print("🔵 [DEBUG] Timestamp age: \(age) seconds")
                print("🔵 [DEBUG] ⚠️  This EXACT timestamp will be used for:")
                print("🔵 [DEBUG]    1. EIP-712 message signing (must match)")
                print("🔵 [DEBUG]    2. Login request to API (must match)")
                print("🔵 [DEBUG] ========================================")
                
                // If timestamp is more than 2 seconds old, it's likely stale
                if age > 2.0 {
                    print("⚠️ [DEBUG] WARNING: Timestamp is \(age)s old - may be rejected by API")
                }
                
                // If timestamp is in the future, there's clock skew
                if age < -1.0 {
                    print("⚠️ [DEBUG] WARNING: Timestamp is \(abs(age))s in the future - clock skew detected")
                }
                
                // CRITICAL: Verify timestamp is still in the message before signing
                // This ensures the message hasn't been modified
                guard let verifyTimestampValue = eip712Response.message["timestamp"]?.value else {
                    print("🔵 [DEBUG] ❌ Timestamp missing from message before signing!")
                    throw WalletError.connectionFailed("Timestamp validation failed: timestamp missing from message")
                }
                
                // Convert to Int for comparison (handle type variations)
                let verifyTimestamp: Int
                if let intVal = verifyTimestampValue as? Int {
                    verifyTimestamp = intVal
                } else if let doubleVal = verifyTimestampValue as? Double {
                    verifyTimestamp = Int(doubleVal)
                } else if let stringVal = verifyTimestampValue as? String, let intFromString = Int(stringVal) {
                    verifyTimestamp = intFromString
                } else {
                    print("🔵 [DEBUG] ❌ Timestamp type mismatch! Expected Int, found: \(type(of: verifyTimestampValue))")
                    throw WalletError.connectionFailed("Timestamp validation failed: invalid type")
                }
                
                guard verifyTimestamp == extractedTimestamp else {
                    print("🔵 [DEBUG] ❌ TIMESTAMP MISMATCH!")
                    print("🔵 [DEBUG] Expected (locked): \(extractedTimestamp)")
                    print("🔵 [DEBUG] Found in message: \(verifyTimestamp)")
                    throw WalletError.connectionFailed("Timestamp validation failed: message changed before signing")
                }
                
                print("🔵 [DEBUG] ✅ Timestamp verified in message before signing: \(extractedTimestamp)")
                
                // Step 3: Sign the message with the EXACT locked timestamp
                if attempt > 0 {
                    print("🔵 [DEBUG] Retry \(attempt): Signing EIP-712 message with LOCKED timestamp \(extractedTimestamp)...")
                } else {
                    print("🔵 [DEBUG] Signing EIP-712 message with LOCKED timestamp \(extractedTimestamp)...")
                }
                
                let signatureStartTime = Date()
                let signature = try await walletService.signEIP712Message(
                    domain: eip712Response.domain,
                    types: eip712Response.types,
                    primaryType: eip712Response.primaryType,
                    message: eip712Response.message
                )
                let signatureEndTime = Date()
                let signingDuration = signatureEndTime.timeIntervalSince(signatureStartTime)
                
                print("🔵 [DEBUG] ✅ Signature received after \(signingDuration)s")
                
                // Calculate timestamp age at the moment we're about to send
                let timestampAgeAtSend = Date().timeIntervalSince(timestampDate)
                print("🔵 [DEBUG] Timestamp age at send time: \(timestampAgeAtSend)s")
                
                // CRITICAL: We MUST use the exact timestamp from the signed message
                // The signature is cryptographically bound to that exact message structure
                // If we change the timestamp, the API's signature verification will fail
                // The API reconstructs the message with the timestamp we send and verifies the signature
                // It will only match if the timestamp matches what was signed
                if timestampAgeAtSend > 2.0 {
                    print("⚠️ [DEBUG] WARNING: Timestamp is \(timestampAgeAtSend)s old")
                    print("⚠️ [DEBUG] The API may reject if timestamp is outside its acceptable window")
                    print("⚠️ [DEBUG] However, we MUST use the exact timestamp from the signed message")
                    if attempt < maxRetries {
                        print("🔵 [DEBUG] Will retry with fresh message if this attempt fails")
                    }
                }
                
                // Step 4: Login IMMEDIATELY after signing (no delays) with the EXACT LOCKED timestamp
                // CRITICAL: The API will reconstruct the EIP-712 message with this timestamp and verify the signature
                // The timestamp MUST be the EXACT same value that was in the signed message
                // Any difference will cause signature verification to fail
                // Note: timestampAgeAtSend was already calculated above for logging
                
                if attempt > 0 {
                    print("🔵 [DEBUG] Retry \(attempt): Sending login request with LOCKED timestamp \(extractedTimestamp)...")
                } else {
                    print("🔵 [DEBUG] Sending login request with LOCKED timestamp \(extractedTimestamp)...")
                }
                
                // Send immediately - no delays to minimize timestamp age
                let loginStartTime = Date()
                
                // FINAL VERIFICATION: Log the exact timestamp we're sending
                print("🔵 [DEBUG] ========================================")
                print("🔵 [DEBUG] ✅ FINAL TIMESTAMP VERIFICATION")
                print("🔵 [DEBUG] ========================================")
                print("🔵 [DEBUG] ✅ LOCKED TIMESTAMP: \(extractedTimestamp)")
                print("🔵 [DEBUG] ✅ Timestamp date: \(timestampDate)")
                print("🔵 [DEBUG] ✅ Timestamp age at send: \(timestampAgeAtSend)s")
                print("🔵 [DEBUG] ✅ This is the EXACT timestamp from the EIP-712 message")
                print("🔵 [DEBUG] ✅ This is the EXACT timestamp that was signed")
                print("🔵 [DEBUG] ✅ API will verify signature using this exact timestamp")
                print("🔵 [DEBUG] ========================================")
                
                let loginResponse = try await PearAPIService.shared.login(
                    address: address,
                    clientId: clientId,
                    signature: signature,
                    timestamp: extractedTimestamp  // Use the LOCKED timestamp - MUST match signed message
                )
                let loginEndTime = Date()
                let loginDuration = loginEndTime.timeIntervalSince(loginStartTime)
                
                // SUCCESS VERIFICATION: If we got here, the timestamp was correct!
                print("🔵 [DEBUG] ========================================")
                print("🔵 [DEBUG] ✅✅✅ AUTHENTICATION SUCCESSFUL ✅✅✅")
                print("🔵 [DEBUG] ========================================")
                print("🔵 [DEBUG] 📋 TIMESTAMP VERIFICATION SUMMARY")
                print("🔵 [DEBUG] ========================================")
                print("🔵 [DEBUG] ✅ LOCKED TIMESTAMP USED: \(extractedTimestamp)")
                print("🔵 [DEBUG] ✅ Timestamp date: \(timestampDate)")
                print("🔵 [DEBUG] ✅ Timestamp was ACCEPTED by API (200 response)")
                print("🔵 [DEBUG] ✅ This confirms the timestamp matched what was in the signed EIP-712 message")
                print("🔵 [DEBUG] ✅ API signature verification passed")
                print("🔵 [DEBUG] ✅ Login completed in \(loginDuration)s")
                print("🔵 [DEBUG] ✅ Total time from extraction to success: \(Date().timeIntervalSince(timestampDate))s")
                print("🔵 [DEBUG] ========================================")
                
                // Step 4: Store tokens
                await AuthService.shared.updateAuthToken(
                    loginResponse.accessToken,
                    refreshToken: loginResponse.refreshToken,
                    expiresIn: loginResponse.expiresIn
                )
                
                // #region agent log
                print("🟡 [HYPO-A,E] Authentication SUCCEEDED - hasAccessToken: \(!loginResponse.accessToken.isEmpty), attempt: \(attempt + 1)")
                // #endregion
                print("🔵 [DEBUG] Authentication successful (attempt \(attempt + 1))")
                return // Success - exit function
            } catch {
                lastError = error
                // #region agent log
                print("🟡 [HYPO-A,E] Authentication attempt \(attempt + 1) FAILED - error: \(error.localizedDescription)")
                // #endregion
                print("🔵 [DEBUG] Authentication attempt \(attempt + 1) failed: \(error.localizedDescription)")
                
                // Check if it's a timestamp error - retry with fresh message
                let isTimestampError = error is TimestampError || error.localizedDescription.lowercased().contains("timestamp")
                
                if isTimestampError && attempt < maxRetries {
                    print("⚠️ [DEBUG] Timestamp validation failed - retrying with fresh message (attempt \(attempt + 2)/\(maxRetries + 1))")
                    // Longer delay before retry to ensure fresh timestamp and account for clock skew
                    // The API validation window is very strict, so we need to give it time
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                    continue // Retry with fresh message
                } else if isTimestampError {
                    print("⚠️ [DEBUG] Timestamp validation failed after \(maxRetries + 1) attempts")
                    print("⚠️ [DEBUG] The API has extremely strict timestamp validation that rejects valid signatures")
                    print("⚠️ [DEBUG] This needs to be fixed on the API side by increasing the validation window")
                }
                
                // If not a timestamp error or max retries reached, throw the error
                if !isTimestampError || attempt >= maxRetries {
                    throw error
                }
            }
        }
        
        // If we get here, all retries failed
        if let error = lastError {
            throw error
        }
    }
    
    func loadInstalledWallets() async {
        installedWallets = await WalletService.shared.checkInstalledWallets()
    }
    
    func createAgentWallet() async {
        print("[WalletVM] ========================================")
        print("[WalletVM] createAgentWallet() - ENTRY POINT")
        print("[WalletVM] ========================================")
        
        // Log input parameters
        let connectedAddress = walletService.connectedAddress
        let keychainToken = KeychainService.shared.authToken
        let hasPendingAddress = keychainService.pendingAgentWalletAddress != nil
        let hasPendingMessage = keychainService.pendingAgentWalletMessage != nil
        let pendingExpiry = keychainService.pendingAgentWalletExpiry
        
        print("[WalletVM] Input parameters:")
        print("[WalletVM]   - connectedAddress: \(connectedAddress ?? "nil")")
        print("[WalletVM]   - hasAuthToken: \(keychainToken != nil)")
        print("[WalletVM]   - authTokenLength: \(keychainToken?.count ?? 0)")
        print("[WalletVM]   - hasPendingAddress: \(hasPendingAddress)")
        print("[WalletVM]   - hasPendingMessage: \(hasPendingMessage)")
        print("[WalletVM]   - pendingExpiry: \(pendingExpiry?.description ?? "nil")")
        print("[WalletVM]   - currentStep: \(currentStep.rawValue)")
        print("[WalletVM]   - isLoading: \(isLoading)")
        
        isLoading = true
        error = nil
        
        // Reuse any pending agent wallet creation to avoid duplicate API calls
        if let pendingAddress = keychainService.pendingAgentWalletAddress,
           let pendingMessage = keychainService.pendingAgentWalletMessage,
           let pendingExpiry = keychainService.pendingAgentWalletExpiry,
           let connectedAddress = walletService.connectedAddress,
           let pendingUserAddress = keychainService.pendingAgentUserWalletAddress,
           pendingUserAddress.caseInsensitiveCompare(connectedAddress) == .orderedSame,
           pendingExpiry > Date() {
            print("[WalletVM] Using pending agent wallet from Keychain instead of creating a new one")
            agentWalletAddress = pendingAddress
            messageToSign = pendingMessage
            isLoading = false
            return
        } else if let pendingExpiry = keychainService.pendingAgentWalletExpiry, pendingExpiry <= Date() {
            print("[WalletVM] Clearing stale pending data (expired)")
            // Clear stale pending data
            keychainService.pendingAgentWalletAddress = nil
            keychainService.pendingAgentWalletMessage = nil
            keychainService.pendingAgentWalletExpiry = nil
            keychainService.pendingAgentUserWalletAddress = nil
        }
        
        // #region agent log
        DebugLogger.log(
            location: "WalletViewModel.swift:320",
            message: "createAgentWallet entry",
            data: [
                "connectedAddress": walletService.connectedAddress ?? "nil",
                "hasKeychainToken": keychainToken != nil,
                "keychainTokenLength": keychainToken?.count ?? 0
            ],
            hypothesisId: "A,B"
        )
        print("🟡 [HYPO-A,B] createAgentWallet entry - connectedAddress: \(walletService.connectedAddress ?? "nil"), hasAuthToken: \(keychainToken != nil)")
        // #endregion
        
        print("🔵 [DEBUG] createAgentWallet() called")
        print("🔵 [DEBUG] Connected address: \(walletService.connectedAddress ?? "nil")")
        
        do {
            print("[WalletVM] Before calling repository method")
            print("[WalletVM] About to call walletRepository.createAgentWallet()")
            
            // Try-Create-First Pattern: Attempt to create agent wallet without auth
            // This works around the timestamp validation issue by only authenticating when required
            print("🔵 [DEBUG] Attempting to create agent wallet (may not require auth)...")
            // #region agent log
            print("🟡 [HYPO-C,D] About to call walletRepository.createAgentWallet (try-create-first)")
            DebugLogger.log(
                location: "WalletViewModel.swift:340",
                message: "About to call walletRepository.createAgentWallet (try-create-first)",
                data: [
                    "hasAuthToken": keychainToken != nil
                ],
                hypothesisId: "C,D"
            )
            // #endregion
            let response = try await walletRepository.createAgentWallet()
            
            print("[WalletVM] Repository method returned successfully")
            print("[WalletVM] Response received:")
            print("[WalletVM]   - agentWalletAddress: \(response.agentWalletAddress)")
            print("[WalletVM]   - messageToSign: \(response.messageToSign.prefix(50))...")
            print("[WalletVM]   - expiresAt: \(response.expiresAt?.description ?? "nil")")
            
            print("[WalletVM] Before writing to Keychain")
            print("[WalletVM] Writing pendingAgentWalletAddress: \(response.agentWalletAddress)")
            
            do {
                keychainService.pendingAgentWalletAddress = response.agentWalletAddress
                print("[Keychain] Write success: pendingAgentWalletAddress")
            } catch {
                print("[Keychain] Write FAILED: pendingAgentWalletAddress - \(error.localizedDescription)")
                print("[Keychain] Error type: \(type(of: error))")
                print("[Keychain] Full error: \(error)")
            }
            
            do {
                keychainService.pendingAgentWalletMessage = response.messageToSign
                print("[Keychain] Write success: pendingAgentWalletMessage")
            } catch {
                print("[Keychain] Write FAILED: pendingAgentWalletMessage - \(error.localizedDescription)")
                print("[Keychain] Error type: \(type(of: error))")
                print("[Keychain] Full error: \(error)")
            }
            
            do {
                keychainService.pendingAgentWalletExpiry = response.expiresAt
                print("[Keychain] Write success: pendingAgentWalletExpiry")
            } catch {
                print("[Keychain] Write FAILED: pendingAgentWalletExpiry - \(error.localizedDescription)")
                print("[Keychain] Error type: \(type(of: error))")
                print("[Keychain] Full error: \(error)")
            }
            
            do {
                keychainService.pendingAgentUserWalletAddress = walletService.connectedAddress
                print("[Keychain] Write success: pendingAgentUserWalletAddress")
            } catch {
                print("[Keychain] Write FAILED: pendingAgentUserWalletAddress - \(error.localizedDescription)")
                print("[Keychain] Error type: \(type(of: error))")
                print("[Keychain] Full error: \(error)")
            }
            
            print("[WalletVM] After writing to Keychain - all operations completed")
            
            // Success! Agent wallet created without authentication
            // #region agent log
            print("🟡 [HYPO-C,D] createAgentWallet succeeded without auth - agentWalletAddress: \(response.agentWalletAddress)")
            // #endregion
            print("🔵 [DEBUG] ✅ Agent wallet created successfully without authentication")
            agentWalletAddress = response.agentWalletAddress
            messageToSign = response.messageToSign
            
            print("[WalletVM] ========================================")
            print("[WalletVM] createAgentWallet() - SUCCESS")
            print("[WalletVM] ========================================")
            // Stay on this step - user must explicitly tap "Continue to Approval"
            
        } catch let apiError as PearAPIError {
            print("[WalletVM] ========================================")
            print("[WalletVM] createAgentWallet() - ERROR CAUGHT")
            print("[WalletVM] ========================================")
            print("[WalletVM] Error type: PearAPIError")
            print("[WalletVM] Error description: \(apiError.localizedDescription)")
            print("[WalletVM] Full error: \(apiError)")
            // Check if it's an authentication required error (401)
            if case .unauthorized = apiError {
                print("[WalletVM] Authentication required (401) - authenticating now...")
                print("🔵 [DEBUG] Agent wallet requires authentication - authenticating now...")
                
                // Only authenticate if explicitly required by API
                do {
                    print("[WalletVM] Calling authenticate()...")
                    try await authenticate()
                    
                    // Verify authentication succeeded
                    let tokenAfterAuth = KeychainService.shared.authToken
                    if tokenAfterAuth == nil {
                        print("[WalletVM] ❌ Authentication completed but no token stored")
                        print("🔵 [DEBUG] ❌ Authentication completed but no token stored")
                        self.error = "Authentication failed. Please try again."
                        showError = true
                        isLoading = false
                        return
                    }
                    
                    print("[WalletVM] ✅ Authentication successful - retrying agent wallet creation...")
                    print("🔵 [DEBUG] ✅ Authentication successful - retrying agent wallet creation...")
                    
                    // Retry creating agent wallet with authentication
                    print("[WalletVM] Retrying walletRepository.createAgentWallet() with auth...")
                    // #region agent log
                    print("🟡 [HYPO-C,D] Retrying walletRepository.createAgentWallet (with auth)")
                    DebugLogger.log(
                        location: "WalletViewModel.swift:380",
                        message: "Retrying walletRepository.createAgentWallet (with auth)",
                        data: [
                            "hasAuthToken": KeychainService.shared.authToken != nil
                        ],
                        hypothesisId: "C,D"
                    )
                    // #endregion
                    let response = try await walletRepository.createAgentWallet()
                    
                    print("[WalletVM] Retry successful - response received")
                    print("[WalletVM]   - agentWalletAddress: \(response.agentWalletAddress)")
                    
                    print("[WalletVM] Writing to Keychain (retry path)...")
                    do {
                        keychainService.pendingAgentWalletAddress = response.agentWalletAddress
                        print("[Keychain] Write success: pendingAgentWalletAddress (retry)")
                    } catch {
                        print("[Keychain] Write FAILED: pendingAgentWalletAddress (retry) - \(error.localizedDescription)")
                    }
                    
                    do {
                        keychainService.pendingAgentWalletMessage = response.messageToSign
                        print("[Keychain] Write success: pendingAgentWalletMessage (retry)")
                    } catch {
                        print("[Keychain] Write FAILED: pendingAgentWalletMessage (retry) - \(error.localizedDescription)")
                    }
                    
                    do {
                        keychainService.pendingAgentWalletExpiry = response.expiresAt
                        print("[Keychain] Write success: pendingAgentWalletExpiry (retry)")
                    } catch {
                        print("[Keychain] Write FAILED: pendingAgentWalletExpiry (retry) - \(error.localizedDescription)")
                    }
                    
                    do {
                        keychainService.pendingAgentUserWalletAddress = walletService.connectedAddress
                        print("[Keychain] Write success: pendingAgentUserWalletAddress (retry)")
                    } catch {
                        print("[Keychain] Write FAILED: pendingAgentUserWalletAddress (retry) - \(error.localizedDescription)")
                    }
                    
                    // #region agent log
                    print("🟡 [HYPO-C,D] createAgentWallet succeeded with auth - agentWalletAddress: \(response.agentWalletAddress)")
                    // #endregion
                    print("🔵 [DEBUG] ✅ Agent wallet created successfully with authentication")
                    agentWalletAddress = response.agentWalletAddress
                    messageToSign = response.messageToSign
                    
                    print("[WalletVM] ========================================")
                    print("[WalletVM] createAgentWallet() - SUCCESS (after retry)")
                    print("[WalletVM] ========================================")
                    
                } catch {
                    print("[WalletVM] ========================================")
                    print("[WalletVM] Authentication FAILED")
                    print("[WalletVM] ========================================")
                    print("[WalletVM] Error type: \(type(of: error))")
                    print("[WalletVM] Error description: \(error.localizedDescription)")
                    print("[WalletVM] Full error: \(error)")
                    print("🔵 [DEBUG] ❌ Authentication failed: \(error.localizedDescription)")
                    
                    // Provide user-friendly error message for timestamp errors
                    let errorMessage: String
                    if error is TimestampError || error.localizedDescription.lowercased().contains("timestamp") {
                        errorMessage = "Authentication failed due to strict timestamp validation. This is a known API limitation. Please tap 'Create Agent Wallet' again to retry - the timing may work on the next attempt."
                    } else {
                        errorMessage = "Authentication failed: \(error.localizedDescription). Please try again."
                    }
                    
                    self.error = errorMessage
                    showError = true
                    print("[WalletVM] Error state set - about to exit authentication catch block")
                }
                print("[WalletVM] Authentication catch block completed")
            } else {
                // Other API error (not authentication-related)
                print("[WalletVM] Non-auth API error")
                // #region agent log
                print("🟡 [HYPO-B,C,D] createAgentWallet FAILED - errorType: PearAPIError, errorMessage: \(apiError.localizedDescription)")
                // #endregion
                print("🔵 [DEBUG] ❌ createAgentWallet API error: \(apiError.localizedDescription)")
                self.error = apiError.localizedDescription
                showError = true
                print("[WalletVM] Non-auth error state set")
            }
            print("[WalletVM] Exiting PearAPIError catch block")
        } catch {
            // Generic error
            print("[WalletVM] ========================================")
            print("[WalletVM] createAgentWallet() - GENERIC ERROR CAUGHT")
            print("[WalletVM] ========================================")
            print("[WalletVM] Error type: \(type(of: error))")
            print("[WalletVM] Error description: \(error.localizedDescription)")
            print("[WalletVM] Full error: \(error)")
            // #region agent log
            print("🟡 [HYPO-B,C,D] createAgentWallet FAILED - errorType: \(type(of: error)), errorMessage: \(error.localizedDescription)")
            print("🟡 [HYPO-B,C,D] Full error: \(error)")
            // #endregion
            print("🔵 [DEBUG] ❌ createAgentWallet error: \(error)")
            print("🔵 [DEBUG] Error type: \(type(of: error))")
            print("🔵 [DEBUG] Error localized: \(error.localizedDescription)")
            self.error = error.localizedDescription
            showError = true
            print("[WalletVM] Generic error state set")
        }
        
        print("[WalletVM] ========================================")
        print("[WalletVM] About to set isLoading = false")
        print("[WalletVM] Current state - isLoading: \(isLoading), error: \(error ?? "nil")")
        isLoading = false
        print("[WalletVM] isLoading set to false")
        print("[WalletVM] ========================================")
        print("[WalletVM] createAgentWallet() - FUNCTION EXIT")
        print("[WalletVM] ========================================")
        print("[WalletVM] Final state - isLoading: \(isLoading), error: \(error ?? "nil")")
        print("[WalletVM] Function is returning now - no more code will execute")
    }
    
    func proceedToApproval() {
        guard agentWalletAddress != nil else {
            error = "Agent wallet not created"
            showError = true
            return
        }
        currentStep = .signAgentApproval
    }
    
    func signAgentApproval() async {
        guard let message = messageToSign,
              let agentAddress = agentWalletAddress else {
            error = "Missing agent wallet data"
            showError = true
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Step 1: Sign agent approval message (MetaMask interaction)
            let signature = try await walletService.signMessage(message)
            
            // Step 2: Submit approval to backend
            try await walletRepository.approveAgentWallet(signature: signature, agentWalletAddress: agentAddress)
            
            // Step 3: Authenticate only if needed to avoid double-prompting the user
            let hasAuthToken = KeychainService.shared.authToken != nil
            let isTokenExpired = AuthService.shared.isTokenExpired
            if !hasAuthToken || isTokenExpired {
                print("🔵 [DEBUG] Authenticating after agent approval (no valid token present)")
                try await authenticate()
            } else {
                print("🔵 [DEBUG] Skipping post-approval authentication (token still valid)")
            }
            
            // Step 4: Advance to builder fee
            currentStep = .approveBuilder
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func approveBuilderFee() async {
        guard let userAddress = connectedAddress,
              let agentAddress = agentWalletAddress else {
            error = "Missing wallet addresses"
            showError = true
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Get builder contract address from config
            let builderContractAddress = Constants.Contracts.builderContractAddress
            
            // Validate contract address
            guard BuilderContractService.shared.validateContractAddress(builderContractAddress) else {
                throw BuilderApprovalError.invalidContractAddress
            }
            
            // Encode the approval transaction calldata
            let calldata = BuilderContractService.shared.encodeBuilderApprovalCalldata(
                userAddress: userAddress,
                agentAddress: agentAddress
            )
            
            print("🔵 [DEBUG] Sending builder approval transaction")
            print("🔵 [DEBUG] Contract: \(builderContractAddress)")
            print("🔵 [DEBUG] Calldata: \(calldata)")
            
            // Send the transaction through WalletConnect
            let txHash = try await walletService.sendTransaction(
                to: builderContractAddress,
                value: "0x0",
                data: calldata
            )
            
            print("🔵 [DEBUG] ✅ Builder approval transaction sent: \(txHash)")
            
            // Store approval status and transaction hash
            walletRepository.setBuilderApproved(true)
            keychainService.set(txHash, forKey: "pear.builder.txHash")
            
            // Trigger success haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            currentStep = .complete
        } catch let walletError as WalletError {
            print("🔵 [DEBUG] ❌ Builder approval failed: \(walletError.localizedDescription)")
            self.error = walletError.localizedDescription
            showError = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        } catch let builderError as BuilderApprovalError {
            print("🔵 [DEBUG] ❌ Builder approval error: \(builderError.localizedDescription)")
            self.error = builderError.localizedDescription
            showError = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        } catch {
            print("🔵 [DEBUG] ❌ Unexpected error: \(error.localizedDescription)")
            self.error = "Failed to approve builder fee: \(error.localizedDescription)"
            showError = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isLoading = false
    }
    
    func disconnect() async {
        print("🔵 [DEBUG] WalletViewModel.disconnect() called")
        await walletService.clearAllConnections()
        keychainService.clearAll()
        await AuthService.shared.clearAuthToken()
        
        // Reset all state
        agentWalletAddress = nil
        messageToSign = nil
        error = nil
        showError = false
        
        currentStep = .welcome
        print("🔵 [DEBUG] Disconnect complete, reset to welcome")
    }
    
    func dismissError() {
        showError = false
        error = nil
    }
}

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case connectWallet = 1
    case createAgentWallet = 2
    case signAgentApproval = 3
    case approveBuilder = 4
    case complete = 5
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Pear"
        case .connectWallet:
            return "Connect Wallet"
        case .createAgentWallet:
            return "Create Agent Wallet"
        case .signAgentApproval:
            return "Approve Agent"
        case .approveBuilder:
            return "Approve Builder Fee"
        case .complete:
            return "All Set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome:
            return "Trade ideas, not tokens"
        case .connectWallet:
            return "Connect your wallet to get started"
        case .createAgentWallet:
            return "Create a delegated trading wallet"
        case .signAgentApproval:
            return "Sign to approve the agent wallet"
        case .approveBuilder:
            return "One-time approval for trading fees"
        case .complete:
            return "You're ready to trade!"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome:
            return "pear"
        case .connectWallet:
            return "wallet.pass.fill"
        case .createAgentWallet:
            return "person.badge.key.fill"
        case .signAgentApproval:
            return "signature"
        case .approveBuilder:
            return "checkmark.seal.fill"
        case .complete:
            return "checkmark.circle.fill"
        }
    }
    
    var progress: Double {
        Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
}
