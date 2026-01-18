import Foundation
import Combine

// MARK: - Pear Repository
/// Data repository for Pear Protocol data with caching and real-time updates
@MainActor
final class PearRepository: ObservableObject {
    static let shared = PearRepository()
    
    // MARK: - Published Data
    @Published private(set) var assets: [Asset] = []
    @Published private(set) var positions: [Position] = []
    @Published private(set) var tradeHistory: [TradeHistoryItem] = []
    @Published private(set) var isLoadingAssets: Bool = false
    @Published private(set) var isLoadingPositions: Bool = false
    @Published private(set) var lastError: String?
    
    // MARK: - Private Properties
    private let apiService = PearAPIService.shared
    private let webSocketService = WebSocketService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupWebSocketSubscriptions()
    }
    
    // MARK: - WebSocket Subscriptions
    private func setupWebSocketSubscriptions() {
        webSocketService.priceUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handlePriceUpdate(update)
            }
            .store(in: &cancellables)
        
        webSocketService.positionUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handlePositionUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Assets
    func fetchAssets() async {
        isLoadingAssets = true
        lastError = nil
        
        do {
            let response = try await apiService.fetchActiveAssets()
            assets = response.assets
            
            // Subscribe to price updates for all assets
            let assetIds = assets.map { $0.id }
            webSocketService.subscribeToPrices(assets: assetIds)
        } catch {
            lastError = error.localizedDescription
            // Use sample data in development
            #if DEBUG
            assets = Asset.sampleAssets
            #endif
        }
        
        isLoadingAssets = false
    }
    
    func searchAssets(query: String) -> [Asset] {
        guard !query.isEmpty else { return assets }
        
        let lowercasedQuery = query.lowercased()
        return assets.filter { asset in
            asset.ticker.lowercased().contains(lowercasedQuery) ||
            asset.name.lowercased().contains(lowercasedQuery)
        }
    }
    
    private func handlePriceUpdate(_ update: PriceUpdate) {
        guard let index = assets.firstIndex(where: { $0.id == update.assetId }) else { return }
        
        assets[index].price = update.price
        assets[index].priceChange24h = update.change24h
        assets[index].priceChangePercent24h = update.changePercent24h
        assets[index].volume24h = update.volume24h
    }
    
    // MARK: - Positions
    func fetchPositions(agentWalletAddress: String) async {
        isLoadingPositions = true
        lastError = nil
        
        do {
            let response = try await apiService.fetchPositions(agentWalletAddress: agentWalletAddress)
            positions = response.positions.filter { $0.status == .open }
            
            // Subscribe to position updates
            webSocketService.subscribeToPositions(userId: agentWalletAddress)
        } catch {
            lastError = error.localizedDescription
            // Use sample data in development
            #if DEBUG
            positions = Position.samplePositions
            #endif
        }
        
        isLoadingPositions = false
    }
    
    private func handlePositionUpdate(_ update: PositionUpdate) {
        guard let index = positions.firstIndex(where: { $0.id == update.positionId }) else { return }
        
        positions[index].currentValue = update.currentValue
        positions[index].unrealizedPnL = update.unrealizedPnL
        positions[index].unrealizedPnLPercent = update.unrealizedPnLPercent
    }
    
    // MARK: - Trade History
    func fetchTradeHistory(agentWalletAddress: String) async {
        do {
            let response = try await apiService.fetchTradeHistory(agentWalletAddress: agentWalletAddress)
            tradeHistory = response.trades
        } catch {
            lastError = error.localizedDescription
            #if DEBUG
            tradeHistory = [TradeHistoryItem.sample]
            #endif
        }
    }
    
    // MARK: - Portfolio Stats
    var totalUnrealizedPnL: Double {
        positions.reduce(0) { $0 + $1.unrealizedPnL }
    }
    
    var totalPortfolioValue: Double {
        positions.reduce(0) { $0 + $1.currentValue }
    }
    
    var totalMarginUsed: Double {
        positions.reduce(0) { $0 + $1.marginUsed }
    }
}

// MARK: - Wallet Repository
@MainActor
final class WalletRepository: ObservableObject {
    static let shared = WalletRepository()
    
    // MARK: - Published State
    @Published private(set) var agentWallet: AgentWallet?
    @Published private(set) var isBuilderApproved: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?
    
    // MARK: - Dependencies
    private let apiService = PearAPIService.shared
    private let walletService = WalletService.shared
    private let keychainService = KeychainService.shared

    private func updateAuthTokenIfPresent(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        AuthService.shared.updateAuthToken(token)
    }
    
    private init() {
        loadStoredState()
    }
    
    // MARK: - Load Stored State
    private func loadStoredState() {
        isBuilderApproved = keychainService.isBuilderApproved
        
        if let address = keychainService.agentWalletAddress,
           let expiry = keychainService.agentWalletExpiry {
            agentWallet = AgentWallet(
                address: address,
                createdAt: expiry.addingTimeInterval(-Double(Constants.AgentWallet.expiryDays * 86400)),
                expiresAt: expiry,
                isApproved: true,
                approvalSignature: nil
            )
        }
    }
    
    // MARK: - Agent Wallet
    func createAgentWallet() async throws -> AgentWalletCreateResponse {
        guard let userAddress = walletService.connectedAddress else {
            throw WalletError.notConnected
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let request = AgentWalletCreateRequest(userWalletAddress: userAddress)
        let response = try await apiService.createAgentWallet(request: request)
        updateAuthTokenIfPresent(response.resolvedAuthToken)
        
        return response
    }
    
    func approveAgentWallet(signature: String, agentWalletAddress: String) async throws {
        guard let userAddress = walletService.connectedAddress else {
            throw WalletError.notConnected
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let request = AgentWalletApproveRequest(
            agentWalletAddress: agentWalletAddress,
            signature: signature,
            userWalletAddress: userAddress
        )
        
        let response = try await apiService.approveAgentWallet(request: request)
        updateAuthTokenIfPresent(response.resolvedAuthToken)
        
        if response.success, let wallet = response.agentWallet {
            agentWallet = wallet
            keychainService.agentWalletAddress = wallet.address
            keychainService.agentWalletExpiry = wallet.expiresAt
        } else {
            throw PearAPIError.invalidRequest(response.message)
        }
    }
    
    func checkAgentWalletStatus() async {
        guard let userAddress = walletService.connectedAddress else { return }
        
        do {
            let response = try await apiService.getAgentWalletStatus(userAddress: userAddress)
            updateAuthTokenIfPresent(response.resolvedAuthToken)
            if let wallet = response.agentWallet {
                agentWallet = wallet
                keychainService.agentWalletAddress = wallet.address
                keychainService.agentWalletExpiry = wallet.expiresAt
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Builder Approval
    func setBuilderApproved(_ approved: Bool) {
        isBuilderApproved = approved
        keychainService.isBuilderApproved = approved
    }
    
    // MARK: - Validation
    var isFullyConfigured: Bool {
        agentWallet?.isValid == true && isBuilderApproved
    }
    
    var needsAgentWalletRefresh: Bool {
        agentWallet?.needsRefresh == true
    }
}
