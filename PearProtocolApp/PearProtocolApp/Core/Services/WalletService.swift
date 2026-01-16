import Foundation
import Combine
import WalletConnectSign
import WalletConnectPairing

// MARK: - Wallet Service
/// Manages WalletConnect integration for wallet connections and signing
@MainActor
final class WalletService: ObservableObject {
    static let shared = WalletService()
    
    // MARK: - Published State
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectedAddress: String?
    @Published private(set) var chainId: Int?
    @Published private(set) var isConnecting: Bool = false
    @Published private(set) var connectionError: String?
    
    // MARK: - Private Properties
    private var session: WalletConnectSign.Session?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Wallet Info
    @Published var walletInfo: WalletInfo?
    
    private init() {
        setupWalletConnect()
        loadStoredSession()
    }
    
    // MARK: - Setup
    private func setupWalletConnect() {
        let projectId = ConfigLoader.loadWalletConnectProjectId() ?? ""
        
        guard !projectId.isEmpty else {
            print("⚠️ WalletConnect Project ID not configured")
            return
        }
        
        let metadata = AppMetadata(
            name: Constants.WalletConnect.appName,
            description: Constants.WalletConnect.appDescription,
            url: Constants.WalletConnect.appURL,
            icons: [Constants.WalletConnect.appIconURL],
            redirect: try? AppMetadata.Redirect(native: "pearprotocol://", universal: nil)
        )
        
        Pair.configure(metadata: metadata)
        
        // Subscribe to session events
        Sign.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.handleSessionsUpdate(sessions)
            }
            .store(in: &cancellables)
        
        Sign.instance.sessionDeletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDisconnect()
            }
            .store(in: &cancellables)
    }
    
    private func loadStoredSession() {
        let sessions = Sign.instance.getSessions()
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
    
    // MARK: - Connection
    func connect() async throws -> String {
        isConnecting = true
        connectionError = nil
        
        defer { isConnecting = false }
        
        do {
            let uri = try await createPairingURI()
            
            // Open wallet app with URI
            if let url = URL(string: "wc:\(uri.absoluteString)") {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
            
            // Wait for session
            let session = try await waitForSession()
            handleSessionConnected(session)
            
            return connectedAddress ?? ""
        } catch {
            connectionError = error.localizedDescription
            throw WalletError.connectionFailed(error.localizedDescription)
        }
    }
    
    private func createPairingURI() async throws -> WalletConnectURI {
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
        
        let uri = try await Pair.instance.create()
        
        try await Sign.instance.connect(
            requiredNamespaces: requiredNamespaces,
            topic: uri.topic
        )
        
        return uri
    }
    
    private func waitForSession() async throws -> WalletConnectSign.Session {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = Sign.instance.sessionSettlePublisher
                .first()
                .timeout(.seconds(120), scheduler: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { session in
                        continuation.resume(returning: session)
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    // MARK: - Disconnect
    func disconnect() async {
        guard let session = session else { return }
        
        do {
            try await Sign.instance.disconnect(topic: session.topic)
        } catch {
            print("Disconnect error: \(error)")
        }
        
        handleDisconnect()
    }
    
    private func handleDisconnect() {
        session = nil
        isConnected = false
        connectedAddress = nil
        chainId = nil
        walletInfo = nil
        
        KeychainService.shared.connectedWalletAddress = nil
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
        self.session = session
        
        // Extract account info
        if let account = session.namespaces["eip155"]?.accounts.first {
            let components = account.absoluteString.split(separator: ":")
            if components.count >= 3 {
                self.chainId = Int(components[1])
                self.connectedAddress = String(components[2])
                self.isConnected = true
                
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
        
        let method = "personal_sign"
        let params = AnyCodable([message, address])
        
        let request = Request(
            topic: session.topic,
            method: method,
            params: params,
            chainId: Blockchain("eip155:\(Constants.Network.arbitrumChainId)")!
        )
        
        do {
            try await Sign.instance.request(params: request)
            
            // Wait for response
            return try await waitForSignatureResponse(topic: session.topic)
        } catch {
            throw WalletError.signingFailed(error.localizedDescription)
        }
    }
    
    private func waitForSignatureResponse(topic: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = Sign.instance.sessionResponsePublisher
                .filter { $0.topic == topic }
                .first()
                .timeout(.seconds(120), scheduler: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { response in
                        switch response.result {
                        case .response(let value):
                            if let signature = try? value.get(String.self) {
                                continuation.resume(returning: signature)
                            } else {
                                continuation.resume(throwing: WalletError.invalidSignature)
                            }
                        case .error(let error):
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
        
        let request = Request(
            topic: session.topic,
            method: method,
            params: params,
            chainId: Blockchain("eip155:\(Constants.Network.arbitrumChainId)")!
        )
        
        do {
            try await Sign.instance.request(params: request)
            return try await waitForTransactionResponse(topic: session.topic)
        } catch {
            throw WalletError.transactionFailed(error.localizedDescription)
        }
    }
    
    private func waitForTransactionResponse(topic: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = Sign.instance.sessionResponsePublisher
                .filter { $0.topic == topic }
                .first()
                .timeout(.seconds(180), scheduler: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { response in
                        switch response.result {
                        case .response(let value):
                            if let txHash = try? value.get(String.self) {
                                continuation.resume(returning: txHash)
                            } else {
                                continuation.resume(throwing: WalletError.transactionFailed("Invalid response"))
                            }
                        case .error(let error):
                            continuation.resume(throwing: WalletError.transactionFailed(error.message))
                        }
                        cancellable?.cancel()
                    }
                )
        }
    }
}

// MARK: - Wallet Errors
enum WalletError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case signingFailed(String)
    case transactionFailed(String)
    case invalidSignature
    case userRejected
    
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
        }
    }
}
