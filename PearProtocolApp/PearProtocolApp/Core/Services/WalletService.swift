import Foundation
import Combine
import WalletConnectSign
import WalletConnectPairing
import WalletConnectNetworking
import WalletConnectRelay
import Starscream
import UIKit

// MARK: - Wallet Service
/// Manages WalletConnect integration for wallet connections and signing
@MainActor
final class WalletService: ObservableObject {
    static let shared: WalletService = {
        print("🔵 [DEBUG] WalletService.shared being initialized")
        return WalletService()
    }()
    
    // MARK: - Published State
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectedAddress: String?
    @Published private(set) var chainId: Int?
    @Published private(set) var isConnecting: Bool = false
    @Published private(set) var connectionError: String?
    @Published private(set) var currentPairingURI: String?
    @Published private(set) var connectionStage: ConnectionStage = .idle
    @Published private(set) var selectedWallet: WalletType?
    
    // MARK: - Private Properties
    private var session: WalletConnectSign.Session?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Wallet Info
    @Published var walletInfo: WalletInfo?
    
    // MARK: - Supported Wallet Schemes
    private let walletSchemes = [
        "metamask://wc?uri=",
        "rainbow://wc?uri=",
        "trust://wc?uri=",
        "safe://wc?uri=",
        "uniswap://wc?uri=",
        "zerion://wc?uri=",
        "cbwallet://wc?uri=",  // Coinbase Wallet
        "rabby://wc?uri=",     // Rabby Wallet
    ]
    
    private init() {
        print("🔵 [DEBUG] WalletService init started")
        setupWalletConnect()
        loadStoredSession()
        print("🔵 [DEBUG] WalletService init completed")
    }
    
    // MARK: - Setup
    private func setupWalletConnect() {
        print("🔵 [DEBUG] setupWalletConnect started")
        let projectId = ConfigLoader.loadWalletConnectProjectId() ?? ""
        
        print("🔵 [DEBUG] Project ID loaded: \(projectId.isEmpty ? "EMPTY" : "✓ Present")")
        
        guard !projectId.isEmpty else {
            print("⚠️ WalletConnect Project ID not configured")
            print("⚠️ Get your project ID from https://cloud.walletconnect.com")
            print("⚠️ Add it to Config.plist under WALLET_CONNECT_PROJECT_ID")
            return
        }
        
        // For WalletConnect v2, the redirect should use the app's bundle identifier format
        // MetaMask needs this to return to the app after approval
        let bundleId = Bundle.main.bundleIdentifier ?? "io.pearprotocol.app"
        let nativeScheme = "pearprotocol://"
        
        print("🔵 [DEBUG] Configuring AppMetadata with redirect: \(nativeScheme)")
        print("🔵 [DEBUG] Bundle ID: \(bundleId)")
        
        let metadata = AppMetadata(
            name: Constants.WalletConnect.appName,
            description: Constants.WalletConnect.appDescription,
            url: Constants.WalletConnect.appURL,
            icons: [Constants.WalletConnect.appIconURL],
            redirect: try! AppMetadata.Redirect(native: nativeScheme, universal: nil)
        )
        
        print("🔵 [DEBUG] About to configure WalletConnect SDK")
        
        // Use proper App Group identifier format
        // For development, we'll use a group identifier format
        // Note: For production, you'll need to enable App Groups capability in Xcode
        let groupIdentifier = "group.io.pearprotocol.app"
        
        print("🔵 [DEBUG] Using group identifier: \(groupIdentifier)")
        
        // Configure WalletConnect SDK for v1.20.3
        // Note: For development, we'll use the bundle identifier as fallback
        // For production, you'll need to enable App Groups capability
        print("🔵 [DEBUG] About to configure Networking")
        
        Networking.configure(
            relayHost: "relay.walletconnect.com",
            groupIdentifier: groupIdentifier,
            projectId: projectId,
            socketFactory: DefaultSocketFactory()
        )
        print("🔵 [DEBUG] Networking configured successfully")
        
        Pair.configure(metadata: metadata)
        Sign.configure(crypto: WalletConnectCryptoProvider())
        print("🔵 [DEBUG] WalletConnect configured (Networking, Pair, Sign)")
        
        // WalletConnect v1.20.3 requires explicit initialization
        // We'll defer Sign.instance access until it's actually needed
        print("🔵 [DEBUG] WalletConnect SDK ready - deferring Sign.instance access")
        
        // Don't subscribe to publishers immediately - do it lazily when needed
        setupSignPublishersLazily()
    }
    
    private func setupSignPublishersLazily() {
        // Defer Sign.instance access - it will be initialized on first use
        Task { @MainActor in
            // Give the SDK time to fully initialize
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            
            print("🔵 [DEBUG] Now setting up Sign publishers")
            
            // Subscribe to session events
            Sign.instance.sessionsPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessions in
                    print("🔵 [DEBUG] Sessions updated: \(sessions.count) sessions")
                    self?.handleSessionsUpdate(sessions)
                }
                .store(in: &self.cancellables)
            
            Sign.instance.sessionDeletePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    print("🔵 [DEBUG] Session deleted")
                    self?.handleDisconnect()
                }
                .store(in: &self.cancellables)
            
            // Listen for session proposal rejections (this helps debug if proposal was received but rejected)
            Sign.instance.sessionRejectionPublisher
                .receive(on: DispatchQueue.main)
                .sink { (proposal, reason) in
                    print("🔵 [DEBUG] ❌ Session proposal REJECTED!")
                    print("🔵 [DEBUG] Proposal ID: \(proposal.id)")
                    print("🔵 [DEBUG] Reason: \(reason.message)")
                    print("🔵 [DEBUG] This means the wallet DID receive the proposal but rejected it")
                }
                .store(in: &self.cancellables)
            
            // Note: pairingStatePublisher is not available in this SDK version
            // We'll monitor pairings manually during connection via getPairings()
            
            print("🔵 [DEBUG] Sign publishers setup completed")
        }
    }
    
    private func loadStoredSession() {
        print("🔵 [DEBUG] loadStoredSession started")
        
        // Check if WalletConnect was configured
        guard ConfigLoader.loadWalletConnectProjectId()?.isEmpty == false else {
            print("🔵 [DEBUG] Skipping loadStoredSession - no project ID configured")
            return
        }
        
        print("🔵 [DEBUG] About to call Sign.instance.getSessions()")
        let sessions = Sign.instance.getSessions()
        print("🔵 [DEBUG] Got \(sessions.count) sessions")
        
        if let activeSession = sessions.first {
            handleSessionConnected(activeSession)
        } else {
            // Check keychain for stored address
            if let storedAddress = KeychainService.shared.connectedWalletAddress {
                // Wallet was previously connected but session expired
                connectedAddress = storedAddress
            }
        }
    }
    
    // MARK: - Debug Bypass
    /// Bypasses wallet connection for development/demo purposes
    /// Sets a fake wallet address and marks as connected
    func bypassConnection() {
        guard Constants.Debug.enableBypass else {
            print("⚠️ [DEBUG] Bypass disabled - not bypassing connection")
            return
        }
        
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] 🚨 DEBUG BYPASS: Wallet Connection")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] ⚠️ WARNING: This is a debug bypass")
        print("🔵 [DEBUG] ⚠️ DO NOT USE IN PRODUCTION")
        print("🔵 [DEBUG] ========================================")
        
        // Set fake wallet address
        let fakeAddress = "0x1234567890123456789012345678901234567890"
        self.connectedAddress = fakeAddress
        self.isConnected = true
        self.chainId = Constants.Network.arbitrumChainId
        
        // Store in keychain for persistence
        KeychainService.shared.connectedWalletAddress = fakeAddress
        
        // Create fake wallet info
        self.walletInfo = WalletInfo(
            address: fakeAddress,
            chainId: Constants.Network.arbitrumChainId,
            ethBalance: 0,
            usdcBalance: 0
        )
        
        print("🔵 [DEBUG] ✅ Bypass complete - fake address set: \(fakeAddress)")
        print("🔵 [DEBUG] ========================================")
    }
    
    // MARK: - Connection
    /// Connects to a wallet using WalletConnect v2 protocol
    ///
    /// **CRITICAL FIX FOR METAMASK iOS:**
    /// MetaMask iOS has a known issue where it doesn't automatically query the relay
    /// for pending session proposals after establishing a pairing. The solution is to use
    /// a two-step flow:
    /// 1. Create pairing URI first (without session proposal)
    /// 2. Open wallet and wait for pairing to be established
    /// 3. THEN create session proposal (which will be sent through the established pairing)
    ///
    /// This ensures MetaMask is fully connected to the relay before the session proposal
    /// is created, allowing it to receive and display the approval popup.
    func connect(walletType: WalletType? = nil) async throws -> String {
        DebugLogger.log(
            location: "WalletService.swift:175",
            message: "connect() called",
            data: [
                "walletType": walletType?.displayName ?? "nil",
                "isAlreadyConnected": isConnected,
                "isConnecting": isConnecting,
                "hasActiveSession": session != nil,
                "currentAddress": connectedAddress ?? "nil"
            ],
            hypothesisId: "F"
        )
        
        // Prevent concurrent connection attempts
        guard !isConnecting else {
            DebugLogger.log(
                location: "WalletService.swift:189",
                message: "Connection already in progress, rejecting duplicate call",
                data: [
                    "walletType": walletType?.displayName ?? "nil"
                ],
                hypothesisId: "F"
            )
            throw WalletError.connectionFailed("Connection already in progress")
        }
        
        isConnecting = true
        connectionError = nil
        connectionStage = .creatingPairing
        
        // Clear any existing auth state to avoid cross-account reuse when switching wallets
        await AuthService.shared.clearAuthToken()
        
        // Store the selected wallet type for later use (signing, etc.)
        selectedWallet = walletType
        print("🔵 [DEBUG] Stored selectedWallet: \(walletType?.displayName ?? "nil")")
        
        defer { 
            isConnecting = false
            if case .connected = connectionStage {
                // Keep connected state
            } else if case .failed = connectionStage {
                // Keep failed state
            } else {
                connectionStage = .idle
            }
        }
        
        do {
            // CRITICAL: Ensure SDK is fully initialized before proceeding
            // WalletConnect docs emphasize that SDK must be initialized immediately
            // This ensures WebSocket connection is ready to receive/send proposals
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] Ensuring SDK is fully initialized...")
            print("🔵 [DEBUG] ========================================")
            
            // Force SDK initialization by accessing Sign.instance
            // This ensures WebSocket connection is established
            _ = Sign.instance.getSessions()
            _ = Pair.instance.getPairings()
            print("🔵 [DEBUG] ✅ SDK instances accessed - WebSocket should be ready")
            
            // Small delay to ensure WebSocket connection is established
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            print("🔵 [DEBUG] ✅ SDK initialization complete")
            
            // REVERSED FLOW FIX: Create session proposal FIRST (combined URI)
            // The two-step flow was causing pairing mismatch - Sign.instance.connect() creates a new pairing
            // instead of using the established one. Solution: Create the session proposal FIRST,
            // which gives us a combined URI that includes both pairing AND session proposal.
            // This ensures the wallet receives everything in one URI, avoiding pairing mismatches.
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] REVERSED FLOW: Session Proposal First (Combined URI)")
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] This fixes the pairing mismatch issue")
            print("🔵 [DEBUG] Step 1: Create session proposal (includes pairing + proposal)")
            print("🔵 [DEBUG] Step 2: Open wallet with combined URI")
            print("🔵 [DEBUG] Step 3: Wait for session settlement")
            print("🔵 [DEBUG] ========================================")
            
            // STEP 1: Create session proposal FIRST (this creates a combined URI)
            connectionStage = .proposingSession
            print("🔵 [DEBUG] STEP 1: Creating session proposal (combined URI)...")
            
            let requiredNamespaces = buildRequiredNamespaces()
            print("🔵 [DEBUG] Required namespaces: \(requiredNamespaces)")
            
            let combinedURI: WalletConnectURI
            do {
                // Sign.instance.connect() creates a combined URI with both pairing and session proposal
                // This is the standard WalletConnect v2 flow and should work with all wallets
                combinedURI = try await Sign.instance.connect(requiredNamespaces: requiredNamespaces)
                print("🔵 [DEBUG] ✅ Combined URI created: \(combinedURI.absoluteString.prefix(100))...")
                print("🔵 [DEBUG] URI topic: \(combinedURI.topic.prefix(16))...")
                print("🔵 [DEBUG] This URI contains BOTH pairing info AND session proposal")
                print("🔵 [DEBUG] The wallet will receive everything in one go")
            } catch {
                print("🔵 [DEBUG] ❌ Failed to create session proposal: \(error)")
                throw WalletError.connectionFailed("Failed to create session proposal: \(error.localizedDescription)")
            }
            
            let uriString = combinedURI.absoluteString
            currentPairingURI = uriString
            
            // Log pairing info for debugging
            let pairingsAfterProposal = Pair.instance.getPairings()
            let activePairings = pairingsAfterProposal.filter { $0.expiryDate > Date() }
            print("🔵 [DEBUG] Active pairings after proposal creation: \(activePairings.count)")
            if let pairing = activePairings.first {
                print("🔵 [DEBUG] Pairing topic: \(pairing.topic.prefix(16))...")
                print("🔵 [DEBUG] Pairing expiry: \(pairing.expiryDate)")
            }
            
            // STEP 2: Open wallet with combined URI
            connectionStage = .openingWallet
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] STEP 2: Opening wallet with combined URI")
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] Combined URI: \(uriString.prefix(100))...")
            print("🔵 [DEBUG] Wallet should:")
            print("🔵 [DEBUG] 1. Parse the WalletConnect URI")
            print("🔵 [DEBUG] 2. Connect to relay using pairing info")
            print("🔵 [DEBUG] 3. Receive the session proposal immediately")
            print("🔵 [DEBUG] 4. Show the approval UI")
            print("🔵 [DEBUG] ========================================")
            
            let walletOpened: Bool
            if let walletType = walletType {
                walletOpened = await openWalletAppWithSimpleEncoding(walletType: walletType, uri: combinedURI)
            } else {
                // Use proper encoding for query parameter values (RFC 3986 unreserved characters only)
                var allowedCharacters = CharacterSet.alphanumerics
                allowedCharacters.insert(charactersIn: "-._~")
                let properlyEncoded = uriString.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? uriString
                walletOpened = await openWalletApp(with: properlyEncoded)
            }
            
            if !walletOpened {
                print("🔵 [DEBUG] ❌ Failed to open wallet app")
                connectionStage = .failed("Wallet app not found")
                throw WalletError.walletNotFound
            }
            
            print("🔵 [DEBUG] ✅ Wallet opened with combined URI")
            
            // Give wallet a moment to process the URI and connect to relay
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] Giving wallet time to process URI and connect to relay...")
            print("🔵 [DEBUG] The wallet should now:")
            print("🔵 [DEBUG] 1. Connect to relay using pairing info from URI")
            print("🔵 [DEBUG] 2. Receive the session proposal")
            print("🔵 [DEBUG] 3. Show the approval UI")
            print("🔵 [DEBUG] ========================================")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Check if session was already created (user approved quickly)
            let sessions = Sign.instance.getSessions()
            print("🔵 [DEBUG] Sessions after opening wallet: \(sessions.count)")
            if !sessions.isEmpty {
                print("🔵 [DEBUG] ✅ Session already created - user approved quickly!")
                if let session = sessions.first {
                    print("🔵 [DEBUG] Session topic: \(session.topic.prefix(16))...")
                }
            } else {
                print("🔵 [DEBUG] ⏳ No session yet - waiting for user approval...")
                print("🔵 [DEBUG] If wallet doesn't show popup, check:")
                print("🔵 [DEBUG] - Wallet app is open and active")
                print("🔵 [DEBUG] - Wallet is connected to relay")
                print("🔵 [DEBUG] - Wallet received the combined URI correctly")
            }
            
            // STEP 3: Wait for user approval in wallet
            connectionStage = .waitingForApproval
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] STEP 3: Waiting for user approval")
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] The wallet should now show the approval UI")
            print("🔵 [DEBUG] If it doesn't appear, check:")
            print("🔵 [DEBUG] - Wallet app is open and active")
            print("🔵 [DEBUG] - Wallet received the combined URI correctly")
            print("🔵 [DEBUG] - Wallet connected to relay")
            print("🔵 [DEBUG] Waiting for session settlement...")
            let session = try await waitForSession()
            
            // Only call handleSessionConnected if we're not already connected
            // (It might have been called already by the sessionsPublisher subscription)
            if !isConnected {
                handleSessionConnected(session)
            } else {
                DebugLogger.log(
                    location: "WalletService.swift:265",
                    message: "Session received but already connected, skipping handleSessionConnected",
                    data: [
                        "sessionTopic": session.topic,
                        "currentAddress": connectedAddress ?? "nil"
                    ],
                    hypothesisId: "F"
                )
            }
            
            connectionStage = .connected
            
            DebugLogger.log(
                location: "WalletService.swift:278",
                message: "connect() completed successfully",
                data: [
                    "address": connectedAddress ?? "unknown",
                    "isConnected": isConnected
                ],
                hypothesisId: "F"
            )
            
            print("🔵 [DEBUG] ✅ Session connected! Address: \(connectedAddress ?? "unknown")")
            
            return connectedAddress ?? ""
        } catch {
            connectionStage = .failed(error.localizedDescription)
            connectionError = error.localizedDescription
            
            if error is WalletError {
                throw error
            } else {
            throw WalletError.connectionFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Mobile Linking (New Implementation)
    /// Opens wallet app using proper WalletConnect v2 mobile linking protocol
    /// This method uses aggressive URI encoding and wallet-specific link formats
    private func openWalletAppWithMobileLink(walletType: WalletType, uri: WalletConnectURI) async -> Bool {
        let uriString = uri.absoluteString
        
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] 📱 MOBILE LINKING")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] Wallet: \(walletType.displayName)")
        print("🔵 [DEBUG] Original URI: \(uriString)")
        
        // Use aggressive percent-encoding for the entire URI
        // WalletConnect URIs contain special characters: : @ ? & = that MUST be encoded
        let aggressivelyEncodedURI = encodeURIForMobileLink(uriString)
        
        print("🔵 [DEBUG] Encoded URI: \(aggressivelyEncodedURI)")
        print("🔵 [DEBUG] ========================================")
        
        switch walletType {
        case .metamask:
            return await tryOpenMetaMaskWithMobileLink(encodedURI: aggressivelyEncodedURI, originalURI: uriString)
        case .coinbase:
            return await tryOpenCoinbaseWithMobileLink(encodedURI: aggressivelyEncodedURI, originalURI: uriString)
        case .rabby:
            return await tryOpenRabbyWithMobileLink(encodedURI: aggressivelyEncodedURI, originalURI: uriString)
        case .rainbow:
            return await tryOpenRainbowWithMobileLink(encodedURI: aggressivelyEncodedURI, originalURI: uriString)
        default:
            return await openWalletApp(walletType: walletType, with: uriString)
        }
    }
    
    /// Opens wallet app with proper encoding for query parameter values
    /// The WC URI must be percent-encoded when passed as the value of ?uri=
    private func openWalletAppWithSimpleEncoding(walletType: WalletType, uri: WalletConnectURI) async -> Bool {
        let uriString = uri.absoluteString
        
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] 📱 QUERY PARAMETER ENCODING")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] Wallet: \(walletType.displayName)")
        print("🔵 [DEBUG] Original URI: \(uriString)")
        
        // CRITICAL: When the WC URI is passed as the VALUE of ?uri=, special characters
        // like @, ?, &, = must be percent-encoded so they don't get interpreted as
        // part of the outer URL structure.
        // .urlQueryAllowed doesn't encode these because they're valid IN query strings,
        // but we need them encoded because the WC URI IS the query parameter value.
        
        // Create a character set that only allows unreserved characters (RFC 3986)
        // This ensures @, ?, &, =, :, / are all encoded
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~") // RFC 3986 unreserved characters
        
        let properlyEncoded = uriString.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? uriString
        
        print("🔵 [DEBUG] Properly encoded URI: \(properlyEncoded.prefix(100))...")
        print("🔵 [DEBUG] Encoding changed: \(uriString != properlyEncoded)")
        print("🔵 [DEBUG] ========================================")
        
        switch walletType {
        case .metamask:
            // Try deep link first (full screen), then universal link
            let deepLink = "metamask://wc?uri=\(properlyEncoded)"
            if let url = URL(string: deepLink) {
                let canOpen = await MainActor.run {
                    UIApplication.shared.canOpenURL(url)
                }
                if canOpen {
                    return await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s delay
                            UIApplication.shared.open(url, options: [:]) { success in
                                print("🔵 [DEBUG] MetaMask deep link result: \(success)")
                                continuation.resume(returning: success)
                            }
                        }
                    }
                }
            }
            // Fallback to universal link
            let universalLink = "https://metamask.app.link/wc?uri=\(properlyEncoded)"
            if let url = URL(string: universalLink) {
                let canOpen = await MainActor.run {
                    UIApplication.shared.canOpenURL(url)
                }
                if canOpen {
                    return await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
                                print("🔵 [DEBUG] MetaMask universal link result: \(success)")
                                continuation.resume(returning: success)
                            }
                        }
                    }
                }
            }
            
        case .coinbase:
            let deepLink = "cbwallet://wc?uri=\(properlyEncoded)"
            if let url = URL(string: deepLink) {
                let canOpen = await MainActor.run {
                    UIApplication.shared.canOpenURL(url)
                }
                if canOpen {
                    return await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            UIApplication.shared.open(url, options: [:]) { success in
                                print("🔵 [DEBUG] Coinbase deep link result: \(success)")
                                continuation.resume(returning: success)
                            }
                        }
                    }
                }
            }
            let universalLink = "https://go.cb-w.com/wc?uri=\(properlyEncoded)"
            if let url = URL(string: universalLink) {
                let canOpen = await MainActor.run {
                    UIApplication.shared.canOpenURL(url)
                }
                if canOpen {
                    return await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
                                print("🔵 [DEBUG] Coinbase universal link result: \(success)")
                                continuation.resume(returning: success)
                            }
                        }
                    }
                }
            }
            
        case .rabby:
            let deepLink = "rabby://wc?uri=\(properlyEncoded)"
            if let url = URL(string: deepLink) {
                let canOpen = await MainActor.run {
                    UIApplication.shared.canOpenURL(url)
                }
                if canOpen {
                    return await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            UIApplication.shared.open(url, options: [:]) { success in
                                print("🔵 [DEBUG] Rabby deep link result: \(success)")
                                continuation.resume(returning: success)
                            }
                        }
                    }
                }
            }
            
        case .rainbow:
            let deepLink = "rainbow://wc?uri=\(properlyEncoded)"
            if let url = URL(string: deepLink) {
                let canOpen = await MainActor.run {
                    UIApplication.shared.canOpenURL(url)
                }
                if canOpen {
                    return await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            UIApplication.shared.open(url, options: [:]) { success in
                                print("🔵 [DEBUG] Rainbow deep link result: \(success)")
                                continuation.resume(returning: success)
                            }
                        }
                    }
                }
            }
            
        default:
            return await openWalletApp(walletType: walletType, with: uriString)
        }
        
        print("🔵 [DEBUG] ❌ Failed to open \(walletType.displayName)")
        return false
    }
    
    /// Encodes a WalletConnect URI for mobile deep linking
    /// Uses standard URL encoding to ensure compatibility
    private func encodeURIForMobileLink(_ uri: String) -> String {
        return uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uri
    }
    
    /// MetaMask mobile linking - Prioritize Universal Links
    private func tryOpenMetaMaskWithMobileLink(encodedURI: String, originalURI: String) async -> Bool {
        // Universal Link is preferred for iOS 13+
        // Format: https://metamask.app.link/wc?uri={encoded_wc_uri}
        
        let strategies: [(name: String, urlString: String)] = [
            // Strategy 1: Universal LINK (Standard) - Preferred
            ("Universal Link", "https://metamask.app.link/wc?uri=\(encodedURI)"),
            
            // Strategy 2: Deep Link (Fallback)
            ("Deep Link", "metamask://wc?uri=\(encodedURI)")
        ]
        
        for (name, urlString) in strategies {
            print("🔵 [DEBUG] MetaMask Strategy: \(name)")
            print("🔵 [DEBUG] URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                 // Use universalLinksOnly for Universal Link to prevent falling back to Safari
                let options: [UIApplication.OpenExternalURLOptionsKey: Any] = urlString.hasPrefix("https://") 
                    ? [.universalLinksOnly: true] 
                    : [:]
                
                let canOpen = await MainActor.run { UIApplication.shared.canOpenURL(url) }
                if canOpen {
                     let success = await MainActor.run {
                        UIApplication.shared.open(url, options: options, completionHandler: nil)
                        return true
                    }
                    if success { return true }
                }
            }
        }
        return false
    }
    
    /// Coinbase Wallet mobile linking
    private func tryOpenCoinbaseWithMobileLink(encodedURI: String, originalURI: String) async -> Bool {
        let strategies: [(name: String, urlString: String)] = [
            ("Universal Link", "https://go.cb-w.com/wc?uri=\(encodedURI)"),
            ("Deep Link", "cbwallet://wc?uri=\(encodedURI)")
        ]
        
        for (_, urlString) in strategies {
            if let url = URL(string: urlString) {
                let options: [UIApplication.OpenExternalURLOptionsKey: Any] = urlString.hasPrefix("https://") 
                    ? [.universalLinksOnly: true] 
                    : [:]
                
                let canOpen = await MainActor.run { UIApplication.shared.canOpenURL(url) }
                 if canOpen {
                     let success = await MainActor.run {
                        UIApplication.shared.open(url, options: options, completionHandler: nil)
                        return true
                    }
                    if success { return true }
                }
            }
        }
        return false
    }    

    
    /// Rabby Wallet mobile linking
    private func tryOpenRabbyWithMobileLink(encodedURI: String, originalURI: String) async -> Bool {
        // encodedURI uses standard encoding
        let strategies: [(name: String, urlString: String)] = [
            ("Deep Link", "rabby://wc?uri=\(encodedURI)")
        ]
        
        for (name, urlString) in strategies {
            print("🔵 [DEBUG] Rabby Strategy: \(name)")
            
            if let url = URL(string: urlString) {
                let canOpen = await MainActor.run { UIApplication.shared.canOpenURL(url) }
                 if canOpen {
                    let success = await MainActor.run {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        return true
                    }
                    if success { return true }
                }
            }
        }
        return false
    }
    
    /// Rainbow Wallet mobile linking
    private func tryOpenRainbowWithMobileLink(encodedURI: String, originalURI: String) async -> Bool {
        // encodedURI uses standard encoding
        let strategies: [(name: String, urlString: String)] = [
            ("Deep Link", "rainbow://wc?uri=\(encodedURI)")
        ]
        
        for (name, urlString) in strategies {
            print("🔵 [DEBUG] Rainbow Strategy: \(name)")
            
            if let url = URL(string: urlString) {
                let canOpen = await MainActor.run { UIApplication.shared.canOpenURL(url) }
                 if canOpen {
                    let success = await MainActor.run {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        return true
                    }
                    if success { return true }
                }
            }
        }
        return false
    }
    
    private func buildRequiredNamespaces() -> [String: ProposalNamespace] {
        // Include both Ethereum mainnet (1) and Arbitrum (42161) for broader wallet support
        // MetaMask requires at least one chain it recognizes
        return [
            "eip155": ProposalNamespace(
                chains: [
                    Blockchain("eip155:1")!,  // Ethereum mainnet - widely supported
                    Blockchain("eip155:\(Constants.Network.arbitrumChainId)")!  // Arbitrum
                ],
                methods: [
                    "eth_sendTransaction",
                    "personal_sign",
                    "eth_signTypedData_v4"
                ],
                events: ["chainChanged", "accountsChanged"]
            )
        ]
    }
    
    // MARK: - Wallet Detection
    func checkInstalledWallets() async -> [WalletType] {
        var installed: [WalletType] = []
        
        for walletType in WalletType.allCases {
            let canOpen = await MainActor.run {
                guard let url = URL(string: walletType.deepLinkScheme) else { return false }
                return UIApplication.shared.canOpenURL(url)
            }
            
            if canOpen {
                installed.append(walletType)
            }
        }
        
        return installed
    }
    
    // MARK: - Open Wallet App
    func openWalletApp(walletType: WalletType, with uri: String) async -> Bool {
        let cleanURI = uri.hasPrefix("wc:") ? String(uri.dropFirst(3)) : uri
        let fullURI = "wc:\(cleanURI)"
        
        print("🔵 [DEBUG] Opening wallet app: \(walletType.displayName)")
        
        // Special handling for MetaMask
        if walletType == .metamask {
            return await tryOpenMetaMask(uri: cleanURI)
        }
        
        // Special handling for Coinbase Wallet
        if walletType == .coinbase {
            return await tryOpenCoinbaseWallet(uri: cleanURI)
        }
        
        // Special handling for Rabby Wallet
        if walletType == .rabby {
            return await tryOpenRabbyWallet(uri: cleanURI)
        }
        
        // For other wallets, use their walletConnectScheme
        guard let encodedURI = fullURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("🔵 [DEBUG] Failed to encode URI for \(walletType.displayName)")
            return false
        }
        
        let urlString = walletType.walletConnectScheme + encodedURI
        guard let url = URL(string: urlString) else {
            print("🔵 [DEBUG] Failed to create URL for \(walletType.displayName)")
            return false
        }
        
        print("🔵 [DEBUG] Trying to open \(walletType.displayName) with URL: \(urlString)")
        
        let canOpen = await MainActor.run {
            UIApplication.shared.canOpenURL(url)
        }
        
        if canOpen {
            return await withCheckedContinuation { continuation in
                Task { @MainActor in
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            print("🔵 [DEBUG] \(walletType.displayName) open callback: \(success)")
                            continuation.resume(returning: success)
                        }
                    } else {
                        let success = UIApplication.shared.openURL(url)
                        continuation.resume(returning: success)
                    }
                }
            }
        } else {
            print("🔵 [DEBUG] Cannot open URL for \(walletType.displayName) - app may not be installed")
        }
        
        return false
    }
    
    // Coinbase Wallet - try multiple approaches
    private func tryOpenCoinbaseWallet(uri: String) async -> Bool {
        let fullURI = "wc:\(uri)"
        
        // Try multiple approaches in order of reliability
        let approaches: [(name: String, urlString: String)] = [
            // Approach 1: Universal link
            ("universal link", "https://go.cb-w.com/wc?uri=\(fullURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullURI)"),
            // Approach 2: Deep link with URI
            ("deep link with URI", "cbwallet://wc?uri=\(fullURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullURI)"),
            // Approach 3: Just open Coinbase - relay should deliver the request
            ("deep link only", "cbwallet://"),
        ]
        
        for (name, urlString) in approaches {
            guard let url = URL(string: urlString) else {
                print("🔵 [DEBUG] Coinbase Wallet URL creation failed for \(name)")
                continue
            }
            
            let canOpen = await MainActor.run {
                UIApplication.shared.canOpenURL(url)
            }
            
            if canOpen {
                print("🔵 [DEBUG] Trying Coinbase Wallet \(name): \(urlString.prefix(100))...")
                let opened = await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        UIApplication.shared.open(url, options: [:]) { success in
                            print("🔵 [DEBUG] Coinbase Wallet \(name) open callback: \(success)")
                            continuation.resume(returning: success)
                        }
                    }
                }
                
                if opened {
                    print("🔵 [DEBUG] ✅ Successfully opened Coinbase Wallet via \(name)")
                    return true
                }
            }
        }
        
        return false
    }
    
    // Rabby Wallet - try multiple approaches
    private func tryOpenRabbyWallet(uri: String) async -> Bool {
        let fullURI = "wc:\(uri)"
        
        // Try multiple approaches in order of reliability
        let approaches: [(name: String, urlString: String)] = [
            // Approach 1: Deep link with URI (standard encoding)
            ("deep link with URI", "rabby://wc?uri=\(fullURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullURI)"),
            // Approach 2: Just open Rabby - relay should deliver the request
            ("deep link only", "rabby://"),
        ]
        
        for (name, urlString) in approaches {
            guard let url = URL(string: urlString) else {
                print("🔵 [DEBUG] Rabby URL creation failed for \(name)")
                continue
            }
            
            let canOpen = await MainActor.run {
                UIApplication.shared.canOpenURL(url)
            }
            
            if canOpen {
                print("🔵 [DEBUG] Trying Rabby \(name): \(urlString.prefix(100))...")
                let opened = await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        UIApplication.shared.open(url, options: [:]) { success in
                            print("🔵 [DEBUG] Rabby \(name) open callback: \(success)")
                            continuation.resume(returning: success)
                        }
                    }
                }
                
                if opened {
                    print("🔵 [DEBUG] ✅ Successfully opened Rabby via \(name)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func openWalletApp(with uri: String) async -> Bool {
        // Extract the URI part (remove wc: prefix if present)
        let cleanURI = uri.hasPrefix("wc:") ? String(uri.dropFirst(3)) : uri
        
        // Try MetaMask first with proper encoding
        if await tryOpenMetaMask(uri: cleanURI) {
            return true
        }
        
        // Try other wallet schemes
        for scheme in walletSchemes where !scheme.contains("metamask") {
            if await tryOpenWallet(scheme: scheme, uri: cleanURI) {
                return true
            }
        }
        
        // Try the generic wc: scheme as last resort
        let wcURLString = uri.hasPrefix("wc:") ? uri : "wc:\(uri)"
        if let wcURL = URL(string: wcURLString) {
            let canOpen = await MainActor.run {
                UIApplication.shared.canOpenURL(wcURL)
            }
            
            if canOpen {
                print("🔵 [DEBUG] Using generic wc: scheme")
                return await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        UIApplication.shared.open(wcURL) { success in
                            continuation.resume(returning: success)
                        }
                    }
                }
            }
        }
        
        print("🔵 [DEBUG] No wallet app found to handle WalletConnect URI")
        return false
    }
    
    // MetaMask - optimized for full-screen approval UI
    private func tryOpenMetaMask(uri: String) async -> Bool {
        let fullURI = "wc:\(uri)"
        
        // FIXED: Deep links FIRST to ensure full-screen opening (fixes 1/4 screen bug)
        // Universal links can open in modal, causing broken UI
        
        let approaches: [(name: String, urlString: String)] = [
            // Approach 1: Deep link with URI (FULL SCREEN - fixes UI bug)
            ("deep link with URI", "metamask://wc?uri=\(fullURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullURI)"),
            // Approach 2: Universal link (fallback - may open in modal)
            ("universal link", "https://metamask.app.link/wc?uri=\(fullURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullURI)"),
            // Approach 3: Just open MetaMask - relay should deliver the request
            ("deep link only", "metamask://"),
        ]
        
        for (name, urlString) in approaches {
            guard let url = URL(string: urlString) else {
                print("🔵 [DEBUG] MetaMask URL creation failed for \(name)")
                continue
            }
            
            let canOpen = await MainActor.run {
                UIApplication.shared.canOpenURL(url)
            }
            
            if canOpen {
                print("🔵 [DEBUG] Trying MetaMask \(name): \(urlString.prefix(100))...")
                
                // Use proper options for deep links vs universal links
                let options: [UIApplication.OpenExternalURLOptionsKey: Any] = urlString.hasPrefix("https://") 
                    ? [.universalLinksOnly: true]
                    : [:]
                
                let opened = await withCheckedContinuation { continuation in
                    Task { @MainActor in
                        // Small delay to ensure app state is ready
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                        
                        UIApplication.shared.open(url, options: options) { success in
                            print("🔵 [DEBUG] MetaMask \(name) open callback: \(success)")
                            if success && urlString.hasPrefix("metamask://") {
                                print("🔵 [DEBUG] ✅ Deep link - MetaMask should show full-screen UI")
                            }
                            continuation.resume(returning: success)
                        }
                    }
                }
                
                if opened {
                    print("🔵 [DEBUG] ✅ Successfully opened MetaMask via \(name)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func tryOpenWallet(scheme: String, uri: String) async -> Bool {
        guard let encodedURI = uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }
        
        let urlString = scheme + encodedURI
        guard let url = URL(string: urlString) else {
            return false
        }
        
        let canOpen = await MainActor.run {
            UIApplication.shared.canOpenURL(url)
        }
        
        if canOpen {
            print("🔵 [DEBUG] Found wallet app: \(scheme)")
            let opened = await withCheckedContinuation { continuation in
                Task { @MainActor in
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            continuation.resume(returning: success)
                        }
                    } else {
                        let success = UIApplication.shared.openURL(url)
                        continuation.resume(returning: success)
                    }
                }
            }
            if opened {
                print("🔵 [DEBUG] Successfully opened wallet app")
                return true
            }
        }
        
        return false
    }
    
    private func createPairingURI() async throws -> WalletConnectURI {
        print("🔵 [DEBUG] createPairingURI() started")
        
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [
                    Blockchain("eip155:\(Constants.Network.arbitrumChainId)")!
                ],
                methods: [
                    "eth_sendTransaction",
                    "personal_sign",
                    "eth_signTypedData_v4"
                ],
                events: ["chainChanged", "accountsChanged"]
            )
        ]
        
        print("🔵 [DEBUG] About to call Pair.instance.create()")
        let uri = try await Pair.instance.create()
        print("🔵 [DEBUG] Pair.instance.create() succeeded - URI: \(uri.absoluteString)")
        
        let pairingTopic = uri.topic
        print("🔵 [DEBUG] URI topic: \(pairingTopic)")
        
        print("🔵 [DEBUG] About to call Sign.instance.connect()")
        _ = try await Sign.instance.connect(requiredNamespaces: requiredNamespaces)
        print("🔵 [DEBUG] Sign.instance.connect() succeeded")
        
        return uri
    }
    
    /// Waits for a pairing to be established with the expected topic
    /// This is used in the two-step flow to ensure the wallet has connected to the relay
    private func waitForPairingEstablishment(expectedTopic: String, timeout: TimeInterval) async throws -> String {
        let result = try await waitForPairingEstablishmentWithObject(expectedTopic: expectedTopic, timeout: timeout)
        return result.topic
    }
    
    /// Waits for a pairing to be established and returns both the pairing object and topic
    /// This allows us to use the pairing object explicitly when creating session proposals
    private func waitForPairingEstablishmentWithObject(expectedTopic: String, timeout: TimeInterval) async throws -> (pairing: WalletConnectPairing.Pairing, topic: String) {
        print("🔵 [DEBUG] Waiting for pairing establishment...")
        print("🔵 [DEBUG] Expected topic: \(expectedTopic.prefix(16))...")
        print("🔵 [DEBUG] Initial pairing count: \(Pair.instance.getPairings().count)")
        
        let checkInterval: TimeInterval = 0.5 // Check every 0.5 seconds
        let maxChecks = Int(timeout / checkInterval)
        
        for i in 0..<maxChecks {
            let pairings = Pair.instance.getPairings()
            let now = Date()
            
            // Look for a pairing that matches our expected topic and is not expired
            if let matchingPairing = pairings.first(where: { $0.topic == expectedTopic && $0.expiryDate > now }) {
                print("🔵 [DEBUG] ✅ Pairing established! Topic: \(matchingPairing.topic.prefix(16))...")
                print("🔵 [DEBUG] Time waited: \(Double(i + 1) * checkInterval) seconds")
                return (pairing: matchingPairing, topic: matchingPairing.topic)
            }
            
            // Also check if any new pairing was created (wallet might use different topic)
            if i >= 5, let newestPairing = pairings.first(where: { $0.expiryDate > now }) {
                // After 2.5 seconds, if we have any valid pairing, use it
                // This handles cases where the wallet creates a new pairing
                print("🔵 [DEBUG] ⚠️ Using newest pairing (topic may differ): \(newestPairing.topic.prefix(16))...")
                return (pairing: newestPairing, topic: newestPairing.topic)
            }
            
            if i < maxChecks - 1 {
                try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
        
        print("🔵 [DEBUG] ❌ Pairing timeout - no pairing established after \(timeout) seconds")
        throw WalletError.pairingTimeout
    }
    
    private func waitForPairingAndGetTopic(uriTopic: String, timeout: TimeInterval) async throws -> String {
        // Give the wallet app time to open and process the URI
        // The wallet needs time to:
        // 1. Open and become active
        // 2. Parse the WalletConnect URI
        // 3. Connect to the relay server
        // We need to wait for the wallet to ACTUALLY establish the pairing
        
        print("🔵 [DEBUG] Waiting for wallet to establish pairing...")
        print("🔵 [DEBUG] Looking for pairing with URI topic: \(uriTopic)")
        print("🔵 [DEBUG] Initial pairing count: \(Pair.instance.getPairings().count)")
        
        // Poll for pairing establishment instead of fixed wait
        // Check every 1 second for up to 30 seconds
        let checkInterval: TimeInterval = 1.0
        let maxChecks = Int(timeout / checkInterval)
        
        for i in 0..<maxChecks {
            let pairings = Pair.instance.getPairings()
            print("🔵 [DEBUG] Check \(i+1)/\(maxChecks): Found \(pairings.count) pairings")
            
            // Look for a pairing that matches our URI topic
            // The pairing topic should match the URI topic in WalletConnect v2
            if let matchingPairing = pairings.first(where: { $0.topic == uriTopic }) {
                // Check if pairing is not expired
                let now = Date()
                if matchingPairing.expiryDate > now {
                    print("🔵 [DEBUG] ✅ Pairing established and active! Topic: \(matchingPairing.topic)")
                    print("🔵 [DEBUG] Pairing expiry: \(matchingPairing.expiryDate)")
                    print("🔵 [DEBUG] Time until expiry: \(matchingPairing.expiryDate.timeIntervalSince(now)) seconds")
                    print("🔵 [DEBUG] Time waited: \(Double(i + 1) * checkInterval) seconds")
                    
                    return matchingPairing.topic
                } else {
                    print("🔵 [DEBUG] ⚠️ Pairing found but expired: \(matchingPairing.topic)")
                }
            }
            
            // If no exact match after several checks, use most recent pairing
            // This handles cases where the pairing topic might differ slightly
            if let mostRecentPairing = pairings.first, i >= 7 {
                // After 7 seconds, if we have any pairing, use it
                let now = Date()
                if mostRecentPairing.expiryDate > now {
                    print("🔵 [DEBUG] ⚠️ Using most recent pairing (no exact match): \(mostRecentPairing.topic)")
                    return mostRecentPairing.topic
                } else {
                    print("🔵 [DEBUG] ⚠️ Most recent pairing is expired")
                }
            }
            
            // Wait before next check
            if i < maxChecks - 1 {
                try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
        
        // If no pairing exists after waiting, throw timeout
        print("🔵 [DEBUG] ❌ Pairing timeout - no pairing established after \(timeout) seconds")
        throw WalletError.pairingTimeout
    }
    
    private func waitForSession() async throws -> WalletConnectSign.Session {
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] ⏳ WAITING FOR SESSION SETTLEMENT")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] Current session count: \(Sign.instance.getSessions().count)")
        print("🔵 [DEBUG] Current pairing count: \(Pair.instance.getPairings().count)")
        
        // Log all current pairings for debugging
        // Note: Pairing doesn't have an 'active' property - check if not expired instead
        let pairings = Pair.instance.getPairings()
        let now = Date()
        for (index, pairing) in pairings.enumerated() {
            let isActive = pairing.expiryDate > now
            print("🔵 [DEBUG] Pairing \(index + 1): topic=\(pairing.topic.prefix(16))..., valid=\(isActive), expiry=\(pairing.expiryDate)")
        }
        
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] Using HYBRID approach: Publisher + Polling")
        print("🔵 [DEBUG] Timeout: 120 seconds")
        print("🔵 [DEBUG] ========================================")
        
        // Use a hybrid approach: both listen to publisher AND poll for sessions
        // This handles cases where the publisher might miss events when app was backgrounded
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WalletConnectSign.Session, Error>) in
            var cancellable: AnyCancellable?
            var pollingTask: Task<Void, Never>?
            var hasResumed = false
            
            // Helper to resume only once
            let resumeOnce: (Result<WalletConnectSign.Session, Error>) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                cancellable?.cancel()
                pollingTask?.cancel()
                
                switch result {
                case .success(let session):
                    continuation.resume(returning: session)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // Start polling task - check for sessions every 2 seconds
            // This catches sessions that appear when app returns from background
            pollingTask = Task { @MainActor in
                var pollCount = 0
                while !hasResumed && pollCount < 60 { // Poll for up to 120 seconds (60 * 2s)
                    pollCount += 1
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    guard !hasResumed else { return }
                    
                    let sessions = Sign.instance.getSessions()
                    print("🔵 [DEBUG] Poll #\(pollCount): Found \(sessions.count) sessions")
                    
                    if let session = sessions.first {
                        print("🔵 [DEBUG] ✅ Session found via polling!")
                        resumeOnce(.success(session))
                        return
                    }
                }
            }
            
            // Also listen to the publisher for immediate notification
            cancellable = Sign.instance.sessionSettlePublisher
                .first()
                .timeout(.seconds(120), scheduler: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        guard !hasResumed else { return }
                        
                        if case .failure(let error) = completion {
                            print("🔵 [DEBUG] ❌ Session settlement timed out or errored: \(error.localizedDescription)")
                            print("🔵 [DEBUG] ========================================")
                            print("🔵 [DEBUG] 🔍 DEBUG INFO - Connection failed")
                            print("🔵 [DEBUG] ========================================")
                            print("🔵 [DEBUG] Final session count: \(Sign.instance.getSessions().count)")
                            print("🔵 [DEBUG] Final pairing count: \(Pair.instance.getPairings().count)")
                            
                            // One last check for sessions before giving up
                            let finalSessions = Sign.instance.getSessions()
                            if let session = finalSessions.first {
                                print("🔵 [DEBUG] ✅ Found session in final check!")
                                resumeOnce(.success(session))
                                return
                            }
                            
                            // Check if any pairings are still valid (not expired)
                            let finalPairings = Pair.instance.getPairings()
                            let currentTime = Date()
                            let validPairings = finalPairings.filter { $0.expiryDate > currentTime }
                            print("🔵 [DEBUG] Valid (non-expired) pairings: \(validPairings.count)")
                            
                            if validPairings.isEmpty {
                                print("🔵 [DEBUG] ⚠️ NO VALID PAIRINGS - Wallet may not have received/parsed the URI")
                                print("🔵 [DEBUG] This suggests the deep link URI was not properly delivered to the wallet")
                                resumeOnce(.failure(WalletError.connectionFailed("Wallet connection failed. Please try again or use a different wallet (Rainbow, Trust Wallet work better).")))
                            } else {
                                print("🔵 [DEBUG] ✅ Valid pairings exist - pairing was created")
                                print("🔵 [DEBUG] ⚠️ Session proposal not received by wallet")
                                print("🔵 [DEBUG] This is a known MetaMask/Rabby iOS limitation")
                                // Create a more helpful error message
                                let walletName = self.selectedWallet?.displayName ?? "Wallet"
                                let helpfulError = WalletError.connectionFailed("\(walletName) connected but didn't show the approval popup. This is a known iOS limitation. Try Rainbow or Trust Wallet, or use the debug bypass for testing.")
                                resumeOnce(.failure(helpfulError))
                            }
                            print("🔵 [DEBUG] ========================================")
                        }
                    },
                    receiveValue: { session in
                        guard !hasResumed else { return }
                        
                        print("🔵 [DEBUG] ========================================")
                        print("🔵 [DEBUG] ✅ SESSION SETTLED via Publisher!")
                        print("🔵 [DEBUG] ========================================")
                        print("🔵 [DEBUG] Session topic: \(session.topic)")
                        print("🔵 [DEBUG] Namespace keys: \(session.namespaces.keys.joined(separator: ", "))")
                        
                        // Extract account info for logging
                        if let account = session.namespaces["eip155"]?.accounts.first {
                            print("🔵 [DEBUG] Account: \(account.absoluteString)")
                        }
                        print("🔵 [DEBUG] ========================================")
                        
                        resumeOnce(.success(session))
                    }
                )
        }
    }
    
    // MARK: - QR Code Generation (for debugging/fallback)
    /// Generates a QR code URI string that can be displayed as a QR code
    /// Use this for testing if deep links are the issue - QR scanning should always work
    func generateQRCodeURI() async throws -> String {
        print("🔵 [DEBUG] Generating QR code URI for debugging...")
        
        // Clean up existing connections
        let existingSessions = Sign.instance.getSessions()
        let existingPairings = Pair.instance.getPairings()
        
        for session in existingSessions {
            try? await Sign.instance.disconnect(topic: session.topic)
        }
        for pairing in existingPairings {
            try? await Pair.instance.disconnect(topic: pairing.topic)
        }
        
        let requiredNamespaces = buildRequiredNamespaces()
        
        // Sign.instance.connect() returns WalletConnectURI (not optional)
        let uri = try await Sign.instance.connect(requiredNamespaces: requiredNamespaces)
        
        currentPairingURI = uri.absoluteString
        
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] 📱 QR CODE URI GENERATED")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] URI: \(uri.absoluteString)")
        print("🔵 [DEBUG] ")
        print("🔵 [DEBUG] To test:")
        print("🔵 [DEBUG] 1. Copy this URI")
        print("🔵 [DEBUG] 2. Generate a QR code from it (use any QR generator)")
        print("🔵 [DEBUG] 3. Scan with MetaMask/Coinbase/Rabby")
        print("🔵 [DEBUG] 4. If approval shows up, deep links are the issue")
        print("🔵 [DEBUG] ========================================")
        
        return uri.absoluteString
    }
    
    // MARK: - Disconnect
    func disconnect() async {
        print("🔵 [DEBUG] disconnect() called")
        
        // Disconnect all sessions
        let sessions = Sign.instance.getSessions()
        for session in sessions {
            do {
                try await Sign.instance.disconnect(topic: session.topic)
                print("🔵 [DEBUG] Disconnected session: \(session.topic)")
            } catch {
                print("🔵 [DEBUG] Error disconnecting session \(session.topic): \(error)")
            }
        }
        
        // Clean up all pairings
        let pairings = Pair.instance.getPairings()
        for pairing in pairings {
            do {
                try await Pair.instance.disconnect(topic: pairing.topic)
                print("🔵 [DEBUG] Disconnected pairing: \(pairing.topic)")
            } catch {
                print("🔵 [DEBUG] Error disconnecting pairing \(pairing.topic): \(error)")
            }
        }
        
        handleDisconnect()
        print("🔵 [DEBUG] Disconnect complete")
    }
    
    /// Clears all stored sessions and pairings - use for fresh start
    func clearAllConnections() async {
        print("🔵 [DEBUG] clearAllConnections() called")
        await disconnect()
        
        // Also clear persisted auth and wallet metadata
        KeychainService.shared.clearAll()
        await AuthService.shared.clearAuthToken()
        
        print("🔵 [DEBUG] All connections cleared")
    }
    
    private func handleDisconnect() {
        session = nil
        isConnected = false
        connectedAddress = nil
        chainId = nil
        walletInfo = nil
        
        // Clear all persisted state when we lose the session to avoid stale auth
        KeychainService.shared.clearAll()
        Task { await AuthService.shared.clearAuthToken() }
    }
    
    // MARK: - Session Handling
    private func handleSessionsUpdate(_ sessions: [WalletConnectSign.Session]) {
        if let activeSession = sessions.first {
            handleSessionConnected(activeSession)
        } else {
            handleDisconnect()
        }
    }
    
    private func handleSessionConnected(_ session: WalletConnectSign.Session) {
        DebugLogger.log(
            location: "WalletService.swift:760",
            message: "handleSessionConnected called",
            data: [
                "sessionTopic": session.topic,
                "hasAccounts": session.namespaces["eip155"]?.accounts.isEmpty == false
            ],
            hypothesisId: "A"
        )
        
        self.session = session
        
        // Extract account info
        if let account = session.namespaces["eip155"]?.accounts.first {
            let components = account.absoluteString.split(separator: ":")
            if components.count >= 3 {
                self.chainId = Int(components[1])
                self.connectedAddress = String(components[2])
                self.isConnected = true
                
                DebugLogger.log(
                    location: "WalletService.swift:769",
                    message: "isConnected set to true",
                    data: [
                        "address": self.connectedAddress ?? "nil",
                        "isConnected": self.isConnected,
                        "source": "handleSessionConnected"
                    ],
                    hypothesisId: "A"
                )
                
                // Store in keychain
                KeychainService.shared.connectedWalletAddress = connectedAddress
                
                // Create wallet info
                self.walletInfo = WalletInfo(
                    address: connectedAddress ?? "",
                    chainId: chainId ?? Constants.Network.arbitrumChainId,
                    ethBalance: 0,
                    usdcBalance: 0
                )
            }
        }
    }
    
    // MARK: - Signing
    func signMessage(_ message: String) async throws -> String {
        guard let session = session,
              let address = connectedAddress else {
            throw WalletError.notConnected
        }
        
        print("🔵 [DEBUG] signMessage called")
        print("🔵 [DEBUG] Original message: \(message)")
        print("🔵 [DEBUG] Message length: \(message.count)")
        
        // CRITICAL: personal_sign expects the message to be hex-encoded (0x-prefixed)
        // According to EIP-191, the message must be converted to hex bytes
        // MetaMask and other wallets expect this format
        let messageData = message.data(using: .utf8) ?? Data()
        let hexMessage = "0x" + messageData.map { String(format: "%02x", $0) }.joined()
        
        print("🔵 [DEBUG] Hex-encoded message: \(hexMessage.prefix(50))... (length: \(hexMessage.count))")
        print("🔵 [DEBUG] ✅ Message is now properly hex-encoded for personal_sign")
        
        let method = "personal_sign"
        // Params: [hexMessage, address] - both should be strings
        let params = AnyCodable([hexMessage, address])
        
        let request = try Request(
            topic: session.topic,
            method: method,
            params: params,
            chainId: Blockchain("eip155:\(Constants.Network.arbitrumChainId)")!
        )
        
        do {            
            print("🔵 [DEBUG] Sending personal_sign request to wallet...")
            _ = try await Sign.instance.request(params: request)
            
            // Open wallet for signing
            await openWalletForSigning()
            
            // Wait for response
            return try await waitForSignatureResponse(topic: session.topic)
        } catch {
            print("🔵 [DEBUG] ❌ signMessage failed: \(error.localizedDescription)")
            throw WalletError.signingFailed(error.localizedDescription)
        }
    }
    
    func signEIP712Message(domain: EIP712Domain, types: EIP712Types, primaryType: String, message: [String: AnyCodable]) async throws -> String {
        print("🔵 [DEBUG] signEIP712Message called")
        print("🔵 [DEBUG] Checking session and address...")
        
        guard let session = session else {
            print("🔵 [DEBUG] ❌ No active session")
            throw WalletError.notConnected
        }
        
        guard let address = connectedAddress else {
            print("🔵 [DEBUG] ❌ No connected address")
            throw WalletError.notConnected
        }
        
        print("🔵 [DEBUG] ✅ Session and address valid")
        print("🔵 [DEBUG] Session topic: \(session.topic)")
        print("🔵 [DEBUG] Address: \(address)")
        
        let method = "eth_signTypedData_v4"
        
        // Build types dictionary - WalletConnect expects nested structure
        // Convert EIP712Types to the format WalletConnect expects
        // CRITICAL: Preserve the exact order of fields as received from API
        var typesDict: [String: Any] = [:]
        
        // #region agent log
        print("🟡 [HYPO-A,C,D] Building types dictionary from API response...")
        print("🟡 [HYPO-A] Checking if EIP712Domain type exists: \(types.types["EIP712Domain"] != nil)")
        print("🟡 [HYPO-C] Types keys from API: \(types.types.keys.sorted())")
        // #endregion
        
        for (typeName, fields) in types.types {
            // #region agent log
            print("🟡 [HYPO-C,D] Processing type '\(typeName)' with \(fields.count) fields:")
            for (index, field) in fields.enumerated() {
                print("🟡 [HYPO-C,D]   Field[\(index)]: name='\(field.name)', type='\(field.type)'")
            }
            // #endregion
            
            // Use an array of dictionaries to preserve field order
            let fieldDicts: [[String: String]] = fields.map { field in
                // CRITICAL: Use ordered dictionary construction to ensure name comes before type
                // This matches the API response format exactly
                ["name": field.name, "type": field.type]
            }
            typesDict[typeName] = fieldDicts
        }
        
        // #region agent log
        // HYPOTHESIS A: Check if we need to add EIP712Domain type
        if typesDict["EIP712Domain"] == nil {
            print("🟡 [HYPO-A] ⚠️ EIP712Domain type NOT in typesDict - adding it explicitly")
            print("🟡 [HYPO-A] Some EIP-712 implementations require EIP712Domain in types")
            // Add EIP712Domain type explicitly - some servers require this
            typesDict["EIP712Domain"] = [
                ["name": "name", "type": "string"],
                ["name": "version", "type": "string"],
                ["name": "chainId", "type": "uint256"],
                ["name": "verifyingContract", "type": "address"]
            ]
            print("🟡 [HYPO-A] ✅ EIP712Domain type added to typesDict")
        }
        // #endregion
        
        // Build domain dictionary
        var domainDict: [String: Any] = [
            "name": domain.name,
            "version": domain.version,
            "chainId": domain.chainId
        ]
        if let verifyingContract = domain.verifyingContract, !verifyingContract.isEmpty {
            domainDict["verifyingContract"] = verifyingContract
        }
        
        // #region agent log
        print("🟡 [HYPO-D,E] Domain dictionary:")
        print("🟡 [HYPO-E]   name: '\(domain.name)'")
        print("🟡 [HYPO-E]   version: '\(domain.version)'")
        print("🟡 [HYPO-E]   chainId: \(domain.chainId) (type: Int)")
        print("🟡 [HYPO-E]   verifyingContract: '\(domain.verifyingContract ?? "nil")'")
        // #endregion
        
        // Build message dictionary (convert AnyCodable to Any)
        // AnyCodable.value extracts the underlying value, handling nested structures
        // CRITICAL: Build messageDict in the EXACT order defined by the types array
        // EIP-712 signature verification depends on field order matching the type definition
        var messageDict: [String: Any] = [:]
        
        // #region agent log
        print("🟡 [HYPO-D] Building message dictionary from AnyCodable values...")
        print("🟡 [HYPO-D] API message keys (raw order - UNORDERED): \(message.keys)")
        // #endregion
        
        // Get the field order from the type definition
        // This ensures the message fields match the order expected by the server
        let primaryTypeFields = types.types[primaryType] ?? []
        
        // #region agent log
        print("🟡 [HYPO-ORDER] Building messageDict in TYPE ORDER (not random dict order)")
        print("🟡 [HYPO-ORDER] Primary type '\(primaryType)' field order:")
        for (index, field) in primaryTypeFields.enumerated() {
            print("🟡 [HYPO-ORDER]   [\(index)] \(field.name) : \(field.type)")
        }
        // #endregion
        
        // Build messageDict in the order defined by the type
        // This is CRITICAL for EIP-712 signature verification
        for field in primaryTypeFields {
            if let value = message[field.name] {
            let extractedValue = value.value
                messageDict[field.name] = extractedValue
            // #region agent log
                print("🟡 [HYPO-D]   \(field.name): \(extractedValue) (in TYPE ORDER, type: \(type(of: extractedValue)))")
            // #endregion
            } else {
                print("⚠️ [HYPO-ORDER] WARNING: Field '\(field.name)' defined in type but not found in message!")
            }
        }
        
        // Check for any extra fields in message not defined in type
        for key in message.keys {
            if !primaryTypeFields.contains(where: { $0.name == key }) {
                print("⚠️ [HYPO-ORDER] WARNING: Field '\(key)' in message but not defined in type!")
            }
        }
        
        // #region agent log
        print("🟡 [HYPO-D] Final messageDict built in TYPE ORDER")
        print("🟡 [HYPO-D] Expected order: \(primaryTypeFields.map { $0.name })")
        // #endregion
        
        // Log the complete message structure being signed
        print("🔵 [DEBUG] 📋 MESSAGE STRUCTURE FOR SIGNING:")
        for (key, value) in messageDict.sorted(by: { $0.key < $1.key }) {
            let typeInfo = type(of: value)
            print("🔵 [DEBUG]   - \(key): \(value) (type: \(typeInfo))")
        }
        
        // CRITICAL: Verify timestamp is in the message that will be signed
        // The timestamp MUST be an Int (not String, not Double) to match what the API expects
        guard let signedTimestamp = messageDict["timestamp"] as? Int else {
            if let stringTimestamp = messageDict["timestamp"] as? String {
                print("🔵 [DEBUG] ❌ TIMESTAMP VERIFICATION ERROR: Timestamp is a String: \(stringTimestamp)")
                print("🔵 [DEBUG] ❌ The API expects an Int timestamp - this will cause signature verification to fail")
            } else if let doubleTimestamp = messageDict["timestamp"] as? Double {
                print("🔵 [DEBUG] ❌ TIMESTAMP VERIFICATION ERROR: Timestamp is a Double: \(doubleTimestamp)")
                print("🔵 [DEBUG] ❌ The API expects an Int timestamp - this will cause signature verification to fail")
        } else {
                print("🔵 [DEBUG] ❌ TIMESTAMP VERIFICATION ERROR: No timestamp found in messageDict!")
            print("🔵 [DEBUG] ❌ Available keys: \(messageDict.keys.sorted())")
            }
            throw WalletError.signingFailed("Invalid timestamp in EIP-712 message: must be Int type")
        }
        
        print("🔵 [DEBUG] ✅ TIMESTAMP VERIFICATION: Timestamp in signed message: \(signedTimestamp) (Int)")
        print("🔵 [DEBUG] ✅ TIMESTAMP VERIFICATION: Timestamp date: \(Date(timeIntervalSince1970: TimeInterval(signedTimestamp)))")
        print("🔵 [DEBUG] ✅ TIMESTAMP VERIFICATION: This timestamp will be cryptographically signed")
        print("🔵 [DEBUG] ✅ TIMESTAMP VERIFICATION: The API must receive this EXACT same timestamp value")
        
        // Build typed data dictionary
        let typedData: [String: Any] = [
            "types": typesDict,
            "primaryType": primaryType,
            "domain": domainDict,
            "message": messageDict
        ]
        
        // Final verification: timestamp in typedData.message
        if let finalMessage = typedData["message"] as? [String: Any],
           let timestamp = finalMessage["timestamp"] as? Int {
            print("🔵 [DEBUG] ✅ TIMESTAMP VERIFICATION: Final timestamp in typedData: \(timestamp)")
        } else if let finalMessage = typedData["message"] as? [String: Any] {
            print("🔵 [DEBUG] ⚠️ TIMESTAMP VERIFICATION: Final message exists but timestamp type is: \(type(of: finalMessage["timestamp"] ?? "nil"))")
        }
        
        // Log the complete typed data structure (for debugging)
        if let jsonData = try? JSONSerialization.data(withJSONObject: typedData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔵 [DEBUG] 📋 COMPLETE TYPED DATA STRUCTURE:")
            print("🔵 [DEBUG] \(jsonString)")
        }
        
        // Params for eth_signTypedData_v4: [address, typedData]
        // CRITICAL: EIP-712 requires message fields in the EXACT order defined in types
        // MetaMask uses the types definition order for hashing, NOT the message object order
        // However, the server might reconstruct using message order, so we must match types order
        
        // Build message JSON string manually with fields in TYPE ORDER
        // This ensures the JSON string has correct order before any parsing/re-serialization
        func jsonEscape(_ string: String) -> String {
            return string.replacingOccurrences(of: "\\", with: "\\\\")
                         .replacingOccurrences(of: "\"", with: "\\\"")
                         .replacingOccurrences(of: "\n", with: "\\n")
                         .replacingOccurrences(of: "\r", with: "\\r")
                         .replacingOccurrences(of: "\t", with: "\\t")
        }
        
        func jsonValue(_ value: Any) -> String {
            if let stringValue = value as? String {
                return "\"\(jsonEscape(stringValue))\""
            } else if let intValue = value as? Int {
                return "\(intValue)"
            } else if let boolValue = value as? Bool {
                return boolValue ? "true" : "false"
        } else {
                return "\"\(value)\""
            }
        }
        
        // Build message JSON in TYPE ORDER
        var messageJsonParts: [String] = []
        for field in primaryTypeFields {
            if let value = messageDict[field.name] {
                messageJsonParts.append("\"\(field.name)\":\(jsonValue(value))")
            }
        }
        let messageJson = "{\(messageJsonParts.joined(separator: ","))}"
        
        // Build types JSON - preserve field order from types definition
        var typesJsonParts: [String] = []
        for (typeName, fields) in typesDict.sorted(by: { $0.key < $1.key }) {
            if let fieldsArray = fields as? [[String: String]] {
                let fieldsJson = fieldsArray.map { field -> String in
                    let name = field["name"] ?? ""
                    let type = field["type"] ?? ""
                    return "{\"name\":\"\(jsonEscape(name))\",\"type\":\"\(jsonEscape(type))\"}"
                }.joined(separator: ",")
                typesJsonParts.append("\"\(jsonEscape(typeName))\":[\(fieldsJson)]")
            }
        }
        let typesJson = "{\(typesJsonParts.joined(separator: ","))}"
        
        // #region agent log
        print("🟡 [HYPO-ORDER] Types JSON: \(typesJson)")
        print("🟡 [HYPO-ORDER] Message JSON: \(messageJson)")
        // #endregion
        
        // Build domain JSON in standard order
        var domainJsonParts: [String] = []
        domainJsonParts.append("\"name\":\"\(jsonEscape(domain.name))\"")
        domainJsonParts.append("\"version\":\"\(jsonEscape(domain.version))\"")
        domainJsonParts.append("\"chainId\":\(domain.chainId)")
        if let verifyingContract = domain.verifyingContract, !verifyingContract.isEmpty {
            domainJsonParts.append("\"verifyingContract\":\"\(jsonEscape(verifyingContract))\"")
        }
        let domainJson = "{\(domainJsonParts.joined(separator: ","))}"
        
        // Build complete typed data JSON string with correct field order
        // Order: types, primaryType, domain, message (standard EIP-712 order)
        let typedDataJson = "{\"types\":\(typesJson),\"primaryType\":\"\(jsonEscape(primaryType))\",\"domain\":\(domainJson),\"message\":\(messageJson)}"
        
        // #region agent log
        print("🟡 [HYPO-ORDER] ========================================")
        print("🟡 [HYPO-ORDER] TYPED DATA JSON (manually built with TYPE ORDER):")
        print("🟡 [HYPO-ORDER] Message field order: \(primaryTypeFields.map { $0.name })")
        print("🟡 [HYPO-ORDER] JSON length: \(typedDataJson.count)")
        print("🟡 [HYPO-ORDER] JSON preview: \(String(typedDataJson.prefix(300)))...")
        print("🟡 [HYPO-ORDER] ========================================")
        // #endregion
        
        // CRITICAL: Send JSON string directly WITHOUT parsing back to dictionary
        // Parsing would lose field order (Swift dictionaries don't preserve order)
        // WalletConnect's AnyCodable should pass the JSON string through to MetaMask
        // MetaMask will parse it and use types definition order for hashing (per EIP-712 spec)
        // The server should also use types order, but if it uses message order, our JSON string has correct order
        
        // #region agent log
        print("🟡 [HYPO-ORDER] ========================================")
        print("🟡 [HYPO-ORDER] FINAL DECISION: Sending JSON STRING directly")
        print("🟡 [HYPO-ORDER] Reason: Parsing to dict would lose field order")
        print("🟡 [HYPO-ORDER] JSON string has message in TYPE ORDER: \(primaryTypeFields.map { $0.name })")
        print("🟡 [HYPO-ORDER] WalletConnect should pass JSON string through to MetaMask")
        print("🟡 [HYPO-ORDER] MetaMask will parse and use types order for hashing")
        print("🟡 [HYPO-ORDER] ========================================")
        // #endregion
        
        var params: AnyCodable
        print("🟡 [HYPO-ORDER] Sending typed data as JSON STRING (preserves field order)")
        print("🟡 [HYPO-ORDER] Message fields in JSON string order: \(primaryTypeFields.map { $0.name })")
        print("🟡 [HYPO-ORDER] JSON string length: \(typedDataJson.count)")
        print("🟡 [HYPO-ORDER] JSON will be passed directly to MetaMask without parsing")
        params = AnyCodable([address, typedDataJson])
        // #endregion
        
        // Verify the typed data structure is valid
        if typesDict.isEmpty {
            print("⚠️ [DEBUG] WARNING: typesDict is empty!")
        }
        if messageDict.isEmpty {
            print("⚠️ [DEBUG] WARNING: messageDict is empty!")
        }
        
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] 📋 EIP-712 SIGNING PARAMETERS")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] Method: \(method)")
        print("🔵 [DEBUG] Address: \(address)")
        print("🔵 [DEBUG] Primary type: \(primaryType)")
        print("🔵 [DEBUG] Domain name: \(domain.name), version: \(domain.version), chainId: \(domain.chainId)")
        print("🔵 [DEBUG] Message keys: \(message.keys.sorted())")
        print("🔵 [DEBUG] Types count: \(typesDict.count)")
        print("🔵 [DEBUG] Message dict count: \(messageDict.count)")
        print("🔵 [DEBUG] ✅ Typed data format: JSON STRING (preserves field order)")
        print("🔵 [DEBUG] ✅ Message field order in JSON: \(primaryTypeFields.map { $0.name })")
        print("🔵 [DEBUG] ✅ Timestamp in message: \(signedTimestamp)")
        print("🔵 [DEBUG] ✅ EIP712Domain in types: \(typesDict["EIP712Domain"] != nil)")
        print("🔵 [DEBUG] ========================================")
        
        let request = try Request(
            topic: session.topic,
            method: method,
            params: params,
            chainId: Blockchain("eip155:\(Constants.Network.arbitrumChainId)")!
        )
        
        do {
            // #region agent log
            print("🟡 [HYPO-SIGN] Sending EIP-712 signing request to wallet...")
            print("🟡 [HYPO-SIGN] Method: \(method)")
            print("🟡 [HYPO-SIGN] Address: \(address)")
            print("🟡 [HYPO-SIGN] Primary type: \(primaryType)")
            print("🟡 [HYPO-SIGN] Session topic: \(session.topic)")
            print("🟡 [HYPO-SIGN] Chain ID: \(Constants.Network.arbitrumChainId)")
            // #endregion
            
            // Send the request FIRST - WalletConnect v2 will handle the notification to the wallet
            print("🔵 [DEBUG] About to call Sign.instance.request...")
            try await Sign.instance.request(params: request)
            print("🔵 [DEBUG] Sign.instance.request completed")
            
            // Open the wallet IMMEDIATELY after sending the request (no delay)
            // WalletConnect v2 should deliver the notification automatically
            // Opening the wallet ensures the user can see and approve the request
            await openWalletForSigning()
            
            // #region agent log
            print("🟡 [HYPO-SIGN] Request sent successfully")
            print("🟡 [HYPO-SIGN] Waiting for signature response on topic: \(session.topic)...")
            // #endregion
            
            return try await waitForSignatureResponse(topic: session.topic)
        } catch {
            // #region agent log
            print("🟡 [HYPO-SIGN] Signing failed: \(error.localizedDescription)")
            // #endregion
            throw WalletError.signingFailed(error.localizedDescription)
        }
    }
    
    /// Opens the wallet app after sending a signing request
    private func openWalletForSigning() async {
        guard let walletType = selectedWallet else {
            // Fallback to MetaMask if no wallet selected
            print("🔵 [DEBUG] selectedWallet is nil, falling back to MetaMask")
            if let url = URL(string: "metamask://") {
                await MainActor.run {
                    if UIApplication.shared.canOpenURL(url) {
                        print("🔵 [DEBUG] Opening MetaMask for signing")
                        UIApplication.shared.open(url)
                    }
                }
            }
            return
        }
        
        print("🔵 [DEBUG] Using selected wallet for signing: \(walletType.displayName)")
        
        // Special handling for Coinbase Wallet - it needs the WalletConnect URI format
        if walletType == .coinbase {
            print("🔵 [DEBUG] Coinbase Wallet detected - attempting to open with WalletConnect URI")
            
            // Try to get an active pairing URI
            // First, try the stored pairing URI
            let pairingURI: String? = currentPairingURI
            
            // If no stored URI, try to get the most recent active pairing
            if pairingURI == nil {
                let pairings = Pair.instance.getPairings()
                let activePairings = pairings.filter { $0.expiryDate > Date() }
                if let mostRecentPairing = activePairings.first {
                    // Try to reconstruct URI from pairing topic
                    // Note: We can't fully reconstruct the URI, but we can try using the topic
                    print("🔵 [DEBUG] Found active pairing with topic: \(mostRecentPairing.topic)")
                    // For now, we'll use the stored URI or fall back to base scheme
                }
            }
            
            // If we have a pairing URI, try to use it
            if let uri = pairingURI {
                // Extract the URI part (after "wc:")
                let uriPart = uri.hasPrefix("wc:") ? String(uri.dropFirst(3)) : uri
                let fullURI = "wc:\(uriPart)"
                
                // Try encoding strategies similar to connection flow
                let encodingStrategies: [(String) -> String?] = [
                    { $0.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) },
                    { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) },
                ]
                
                for (index, encode) in encodingStrategies.enumerated() {
                    guard let encoded = encode(fullURI) else { continue }
                    let urlString = "cbwallet://wc?uri=\(encoded)"
                    
                    guard let url = URL(string: urlString) else { continue }
                    
                    let canOpen = await MainActor.run {
                        UIApplication.shared.canOpenURL(url)
                    }
                    
                    if canOpen {
                        print("🔵 [DEBUG] Opening Coinbase Wallet with URI (strategy \(index)): \(urlString)")
                        await MainActor.run {
                            UIApplication.shared.open(url, options: [:]) { success in
                                print("🔵 [DEBUG] Coinbase Wallet open callback: \(success)")
                            }
                        }
                        return
                    }
                }
            }
            
            // Fallback: just open the base scheme
            // WalletConnect v2 should still deliver the request notification
            print("🔵 [DEBUG] Opening Coinbase Wallet with base scheme (no URI available)")
            print("🔵 [DEBUG] WalletConnect should deliver the signing request notification")
            if let url = URL(string: "cbwallet://") {
                await MainActor.run {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            print("🔵 [DEBUG] Coinbase Wallet base scheme open callback: \(success)")
                        }
                    } else {
                        print("🔵 [DEBUG] Cannot open Coinbase Wallet - app may not be installed")
                    }
                }
            }
            return
        }
        
        // Special handling for Rabby Wallet - it needs the WalletConnect URI format
        if walletType == .rabby {
            print("🔵 [DEBUG] Rabby Wallet detected - attempting to open with WalletConnect URI")
            
            // Try to get an active pairing URI
            // First, try the stored pairing URI
            let pairingURI: String? = currentPairingURI
            
            // If no stored URI, try to get the most recent active pairing
            if pairingURI == nil {
                let pairings = Pair.instance.getPairings()
                let activePairings = pairings.filter { $0.expiryDate > Date() }
                if let mostRecentPairing = activePairings.first {
                    print("🔵 [DEBUG] Found active pairing with topic: \(mostRecentPairing.topic)")
                    // For now, we'll use the stored URI or fall back to base scheme
                }
            }
            
            // If we have a pairing URI, try to use it
            if let uri = pairingURI {
                // Extract the URI part (after "wc:")
                let uriPart = uri.hasPrefix("wc:") ? String(uri.dropFirst(3)) : uri
                let fullURI = "wc:\(uriPart)"
                
                // Try encoding strategies similar to connection flow
                let encodingStrategies: [(String) -> String?] = [
                    { $0.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) },
                    { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) },
                ]
                
                for (index, encode) in encodingStrategies.enumerated() {
                    guard let encoded = encode(fullURI) else { continue }
                    let urlString = "rabby://wc?uri=\(encoded)"
                    
                    guard let url = URL(string: urlString) else { continue }
                    
                    let canOpen = await MainActor.run {
                        UIApplication.shared.canOpenURL(url)
                    }
                    
                    if canOpen {
                        print("🔵 [DEBUG] Opening Rabby Wallet with URI (strategy \(index)): \(urlString)")
                        await MainActor.run {
                            UIApplication.shared.open(url, options: [:]) { success in
                                print("🔵 [DEBUG] Rabby Wallet open callback: \(success)")
                            }
                        }
                        return
                    }
                }
            }
            
            // Fallback: just open the base scheme
            // WalletConnect v2 should still deliver the request notification
            print("🔵 [DEBUG] Opening Rabby Wallet with base scheme (no URI available)")
            print("🔵 [DEBUG] WalletConnect should deliver the signing request notification")
            if let url = URL(string: "rabby://") {
                await MainActor.run {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:]) { success in
                            print("🔵 [DEBUG] Rabby Wallet base scheme open callback: \(success)")
                        }
                    } else {
                        print("🔵 [DEBUG] Cannot open Rabby Wallet - app may not be installed")
                    }
                }
            }
            return
        }
        
        // For other wallets, use the base deep link scheme
        // WalletConnect v2 should handle notifications automatically
        let deepLinkScheme = walletType.deepLinkScheme
        if let url = URL(string: deepLinkScheme) {
            await MainActor.run {
                print("🔵 [DEBUG] Attempting to open \(walletType.displayName) for signing: \(url)")
                if UIApplication.shared.canOpenURL(url) {
                    print("🔵 [DEBUG] Opening \(walletType.displayName) for signing")
                    UIApplication.shared.open(url)
                } else {
                    print("🔵 [DEBUG] Cannot open URL: \(url) - wallet may not be installed")
                }
            }
        }
    }
    
    private func waitForSignatureResponse(topic: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            print("🟡 [HYPO-SIG] Setting up response listener for topic: \(topic)")
            
            cancellable = Sign.instance.sessionResponsePublisher
                .handleEvents(receiveOutput: { response in
                    print("🟡 [HYPO-SIG] Received response on topic: \(response.topic), expected: \(topic)")
                })
                .filter { $0.topic == topic }
                .first()
                .timeout(.seconds(120), scheduler: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            print("🟡 [HYPO-SIG] Response publisher completed")
                        case .failure(let error):
                            print("🟡 [HYPO-SIG] Response publisher error: \(error)")
                            let errorMessage = error.localizedDescription
                            if errorMessage.contains("timeout") || errorMessage.contains("Timeout") {
                                continuation.resume(throwing: WalletError.signingFailed("Signature request timed out. Please check MetaMask and try again."))
                            } else {
                                continuation.resume(throwing: WalletError.signingFailed(errorMessage))
                            }
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { response in
                        print("🟡 [HYPO-SIG] Processing response...")
                        switch response.result {
                        case .response(let value):
                            if let signature = try? value.get(String.self) {
                                // #region agent log
                                print("🟡 [HYPO-SIG] Signature received - length: \(signature.count), starts with 0x: \(signature.hasPrefix("0x"))")
                                print("🟡 [HYPO-SIG] Signature preview: \(String(signature.prefix(20)))...")
                                
                                // HYPOTHESIS B: Analyze signature v-value
                                // EIP-712 signatures are 65 bytes: r(32) + s(32) + v(1)
                                // Hex: 130 chars for r+s, 2 chars for v, plus "0x" prefix = 132 chars
                                if signature.hasPrefix("0x") && signature.count == 132 {
                                    let vHex = String(signature.suffix(2))  // Last 2 hex chars = v value
                                    if let vValue = UInt8(vHex, radix: 16) {
                                        print("🟡 [HYPO-B] Signature v-value: \(vValue) (0x\(vHex))")
                                        print("🟡 [HYPO-B] v=27 or v=28 is standard Ethereum format")
                                        print("🟡 [HYPO-B] v=0 or v=1 is EIP-155/normalized format")
                                        if vValue == 27 || vValue == 28 {
                                            print("🟡 [HYPO-B] ✅ v-value is standard (27/28) - server may expect this OR 0/1")
                                            let normalizedV = vValue - 27
                                            print("🟡 [HYPO-B] If server expects normalized: would be v=\(normalizedV)")
                                        } else if vValue == 0 || vValue == 1 {
                                            print("🟡 [HYPO-B] v-value is already normalized (0/1)")
                                        } else {
                                            print("🟡 [HYPO-B] ⚠️ Unusual v-value: \(vValue)")
                                        }
                                    }
                                }
                                // #endregion
                                continuation.resume(returning: signature)
                            } else {
                                // #region agent log
                                print("🟡 [HYPO-SIG] Failed to parse signature from response")
                                print("🟡 [HYPO-SIG] Response value type: \(type(of: value))")
                                // #endregion
                                continuation.resume(throwing: WalletError.invalidSignature)
                            }
                        case .error(let error):
                            // #region agent log
                            print("🟡 [HYPO-SIG] Signing error from wallet: \(error.message)")
                            print("🟡 [HYPO-SIG] Error code: \(error.code)")
                            // #endregion
                            continuation.resume(throwing: WalletError.signingFailed(error.message))
                        }
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    // MARK: - Transactions
    func sendTransaction(
        to: String,
        value: String,
        data: String
    ) async throws -> String {
        guard let session = session,
              let address = connectedAddress else {
            throw WalletError.notConnected
        }
        
        let transaction: [String: String] = [
            "from": address,
            "to": to,
            "value": value,
            "data": data
        ]
        
        let method = "eth_sendTransaction"
        let params = AnyCodable([transaction])
        
        let request = try Request(
            topic: session.topic,
            method: method,
            params: params,
            chainId: Blockchain("eip155:\(Constants.Network.arbitrumChainId)")!
        )
        
        do {
            // #region agent log
            print("🟡 [HYPO-TX] Sending transaction request to wallet...")
            print("🟡 [HYPO-TX] Method: \(method)")
            print("🟡 [HYPO-TX] To: \(to)")
            print("🟡 [HYPO-TX] Value: \(value)")
            print("🟡 [HYPO-TX] Data length: \(data.count)")
            print("🟡 [HYPO-TX] Session topic: \(session.topic)")
            // #endregion
            
            // Send the request FIRST - WalletConnect v2 will handle the notification to the wallet
            print("🔵 [DEBUG] About to call Sign.instance.request for transaction...")
            try await Sign.instance.request(params: request)
            print("🔵 [DEBUG] Sign.instance.request completed for transaction")
            
            // Open the wallet IMMEDIATELY after sending the request (no delay)
            // WalletConnect v2 should deliver the notification automatically
            // Opening the wallet ensures the user can see and approve the transaction
            await openWalletForSigning()
            
            // #region agent log
            print("🟡 [HYPO-TX] Request sent successfully")
            print("🟡 [HYPO-TX] Waiting for transaction response on topic: \(session.topic)...")
            // #endregion
            
            return try await waitForTransactionResponse(topic: session.topic)
        } catch {
            print("🔵 [DEBUG] ❌ Transaction request failed: \(error.localizedDescription)")
            throw WalletError.transactionFailed(error.localizedDescription)
        }
    }
    
    private func waitForTransactionResponse(topic: String) async throws -> String {
        // #region agent log
        print("🟡 [HYPO-TX] Setting up transaction response listener for topic: \(topic)")
        // #endregion
        
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = Sign.instance.sessionResponsePublisher
                .filter { $0.topic == topic }
                .first()
                .timeout(.seconds(180), scheduler: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            // #region agent log
                            print("🟡 [HYPO-TX] Transaction response timeout or error: \(error.localizedDescription)")
                            // #endregion
                            continuation.resume(throwing: WalletError.transactionFailed(error.localizedDescription))
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { response in
                        // #region agent log
                        print("🟡 [HYPO-TX] Received transaction response on topic: \(response.topic)")
                        // #endregion
                        
                        switch response.result {
                        case .response(let value):
                            if let txHash = try? value.get(String.self) {
                                // #region agent log
                                print("🟡 [HYPO-TX] ✅ Transaction hash received: \(txHash)")
                                // #endregion
                                continuation.resume(returning: txHash)
                            } else {
                                // #region agent log
                                print("🟡 [HYPO-TX] ❌ Invalid transaction response format")
                                // #endregion
                                continuation.resume(throwing: WalletError.transactionFailed("Invalid response"))
                            }
                        case .error(let error):
                            // #region agent log
                            print("🟡 [HYPO-TX] ❌ Transaction error from wallet: \(error.message)")
                            print("🟡 [HYPO-TX] Error code: \(error.code)")
                            // #endregion
                            continuation.resume(throwing: WalletError.transactionFailed(error.message))
                        }
                        cancellable?.cancel()
                    }
                )
        }
    }
}

// MARK: - WebSocket Factory
// Adapter to make Starscream.WebSocket conform to WebSocketConnecting
private final class StarscreamAdapter: NSObject, WebSocketConnecting {
    private let socket: Starscream.WebSocket
    private let queue = DispatchQueue(label: "com.walletconnect.sdk.sockets", qos: .utility)
    private var _isConnected: Bool = false
    private let _request: URLRequest
    
    var request: URLRequest {
        get { _request }
        set { /* Starscream doesn't support changing request after init */ }
    }
    
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    var isConnected: Bool {
        _isConnected
    }
    
    init(socket: Starscream.WebSocket) {
        print("🔵 [DEBUG] StarscreamAdapter.init started")
        self.socket = socket
        self._request = socket.request
        super.init()
        socket.delegate = self
        socket.callbackQueue = queue
        print("🔵 [DEBUG] StarscreamAdapter.init completed")
    }
    
    func connect() {
        socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    func write(string: String, completion: (() -> Void)?) {
        socket.write(string: string, completion: completion)
    }
    
    func write(data: Data, completion: (() -> Void)?) {
        socket.write(data: data, completion: completion)
    }
}

extension StarscreamAdapter: WebSocketDelegate {
    nonisolated func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
        switch event {
        case .connected:
            Task { @MainActor in
                self._isConnected = true
                self.onConnect?()
            }
        case .disconnected(let reason, _):
            Task { @MainActor in
                self._isConnected = false
                let error = NSError(domain: "WalletConnect", code: -1, userInfo: [NSLocalizedDescriptionKey: reason])
                self.onDisconnect?(error)
            }
        case .text(let text):
            onText?(text)
        case .error(let error):
            Task { @MainActor in
                self._isConnected = false
                self.onError?(error ?? NSError(domain: "WalletConnect", code: -1))
                self.onDisconnect?(error)
            }
        default:
            break
        }
    }
}

private struct DefaultSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        print("🔵 [DEBUG] DefaultSocketFactory.create called with URL: \(url)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let socket = Starscream.WebSocket(
            request: request,
            certPinner: nil,
            compressionHandler: nil,
            useCustomEngine: true
        )
        print("🔵 [DEBUG] Created Starscream.WebSocket, creating adapter")
        
        let adapter = StarscreamAdapter(socket: socket)
        print("🔵 [DEBUG] StarscreamAdapter created successfully")
        
        return adapter
    }
}

// MARK: - Wallet Errors
// MARK: - Connection Stage
enum ConnectionStage: Equatable {
    case idle
    case creatingPairing
    case openingWallet
    case establishingPairing
    case proposingSession
    case waitingForApproval
    case connected
    case failed(String)
    
    var displayMessage: String {
        switch self {
        case .idle:
            return ""
        case .creatingPairing:
            return "Creating connection..."
        case .openingWallet:
            return "Opening wallet app..."
        case .establishingPairing:
            return "Establishing connection..."
        case .proposingSession:
            return "Requesting permission..."
        case .waitingForApproval:
            return "Waiting for approval in wallet..."
        case .connected:
            return "Connected!"
        case .failed(let message):
            return "Error: \(message)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .idle:
            return false
        default:
            return true
        }
    }
}

enum WalletError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case signingFailed(String)
    case transactionFailed(String)
    case invalidSignature
    case userRejected
    case pairingTimeout
    case walletNotFound
    case sessionProposalRejected
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Wallet not connected. Please connect your wallet."
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .signingFailed(let message):
            return "Signing failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .invalidSignature:
            return "Invalid signature received."
        case .userRejected:
            return "Request rejected by user."
        case .pairingTimeout:
            return "Pairing timeout. Please make sure your wallet app is open and try again."
        case .walletNotFound:
            return "Wallet app not found. Please install a supported wallet."
        case .sessionProposalRejected:
            return "Connection request was rejected. Please try again."
        }
    }
}
