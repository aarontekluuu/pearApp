import Foundation
import Combine
import Alamofire

// MARK: - Pear Repository
/// Data repository for Pear Protocol data with caching and real-time updates
@MainActor
final class PearRepository: ObservableObject {
    static let shared = PearRepository()
    
    // MARK: - Published Data
    @Published private(set) var assets: [Asset] = []
    @Published private(set) var positions: [Position] = []
    @Published private(set) var tradeHistory: [TradeHistoryItem] = []
    @Published private(set) var marketData: MarketDataResponse?
    @Published private(set) var isLoadingAssets: Bool = false
    @Published private(set) var isLoadingPositions: Bool = false
    @Published private(set) var isLoadingMarketData: Bool = false
    @Published private(set) var lastError: String?
    
    // MARK: - Private Properties
    private let apiService = PearAPIService.shared
    private let webSocketService = WebSocketService.shared
    private var cancellables = Set<AnyCancellable>()
    private var pricePollingTimer: Timer?
    private var lastPriceUpdateTime: Date?
    
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
        
        // Subscribe to market data updates from WebSocket
        webSocketService.marketDataUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleMarketDataUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Assets
    func fetchAssets() async {
        isLoadingAssets = true
        lastError = nil

        
        print("🔵 [DEBUG] fetchAssets() called")
        print("🔵 [DEBUG] API endpoint: \(Constants.API.baseURL)\(Constants.API.activeAssets)")
        
        do {
            let response = try await apiService.fetchActiveAssets()
            print("🔵 [DEBUG] ✅ fetchAssets() succeeded")
            print("🔵 [DEBUG] Active groups: \(response.active.count)")
            print("🔵 [DEBUG] Top gainers: \(response.topGainers.count)")
            print("🔵 [DEBUG] Top losers: \(response.topLosers.count)")
            
            // Extract unique assets from all groups (active, topGainers, topLosers, highlighted, watchlist)
            let allGroups = response.active + response.topGainers + response.topLosers + response.highlighted + response.watchlist
            let extractedAssets = extractUniqueAssets(from: allGroups)
            
            print("🔵 [DEBUG] Extracted \(extractedAssets.count) unique assets")
            assets = extractedAssets
            
            if assets.isEmpty {
                print("🔵 [DEBUG] ⚠️ WARNING: Assets array is empty - no assets found in groups")
            } else {
                print("🔵 [DEBUG] Sample assets: \(assets.prefix(3).map { $0.ticker }.joined(separator: ", "))")
            }
            
            // Subscribe to price updates for all assets
            let assetIds = assets.map { $0.id }
            
            // #region agent log
            DebugLogger.log(
                location: "PearRepository.swift:84",
                message: "About to subscribe to price updates",
                data: [
                    "assetCount": assets.count,
                    "assetIds": assetIds,
                    "assetIdsLowercase": assetIds.map { $0.lowercased() },
                    "sampleAssets": assets.prefix(3).map { ["id": $0.id, "ticker": $0.ticker, "price": $0.price] },
                    "isWebSocketConnected": webSocketService.isConnected
                ],
                hypothesisId: "PRICE-1,PRICE-3"
            )
            // #endregion
            
            // Wait for WebSocket connection before subscribing
            if !webSocketService.isConnected {
                print("🔵 [DEBUG] WebSocket not connected - waiting for connection...")
                var attempts = 0
                while !webSocketService.isConnected && attempts < 30 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    attempts += 1
                }
                
                if webSocketService.isConnected {
                    print("🔵 [DEBUG] ✅ WebSocket connected after waiting")
                } else {
                    print("🔵 [DEBUG] ⚠️ WebSocket still not connected after 3 seconds - subscribing anyway (will queue)")
                }
            }
            
            webSocketService.subscribeToPrices(assets: assetIds)
            
            // Start polling as fallback for price updates
            startPricePolling()
            
            // Fetch initial market prices to populate prices
            Task {
                await fetchMarketPrices()
            }
        } catch {
            let errorMessage = error.localizedDescription
            print("🔵 [DEBUG] ❌ fetchAssets() failed: \(errorMessage)")
            print("🔵 [DEBUG] Error type: \(type(of: error))")
            if let afError = error as? AFError {
                print("🔵 [DEBUG] AFError details: \(afError)")
                if let responseCode = afError.responseCode {
                    print("🔵 [DEBUG] Response status code: \(responseCode)")
                }
            }
            lastError = errorMessage
        }
        
        isLoadingAssets = false
    }
    
    // MARK: - Price Polling
    /// Starts polling for market prices every 10 seconds as fallback if WebSocket fails
    private func startPricePolling() {
        // Stop existing timer if any
        pricePollingTimer?.invalidate()
        
        // Poll every 10 seconds
        pricePollingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchMarketPrices()
            }
        }
        
        // Add timer to run loop
        if let timer = pricePollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🔵 [DEBUG] ✅ Price polling started (every 10 seconds)")
    }
    
    /// Fetches current market prices from Hyperliquid (primary) and CoinGecko (fallback)
    func fetchMarketPrices() async {
        guard !assets.isEmpty else {
            print("🔵 [DEBUG] ⚠️ No assets to update prices for")
            return
        }
        
        let tickers = assets.map { $0.ticker }
        print("🔵 [DEBUG] Fetching prices for \(tickers.count) assets...")
        
        // Try Hyperliquid first (covers all Hyperliquid tokens)
        var prices = await SharedCoinGeckoService.shared.fetchHyperliquidPrices(for: tickers)
        var updatedCount = prices.count
        var source = "Hyperliquid"
        
        // If Hyperliquid didn't return all prices, try CoinGecko for remaining
        if updatedCount < assets.count {
            let remainingTickers = tickers.filter { ticker in
                !prices.keys.contains(where: { $0.uppercased() == ticker.uppercased() })
            }
            
            if !remainingTickers.isEmpty {
                print("🔵 [DEBUG] Fetching \(remainingTickers.count) remaining prices from CoinGecko...")
                let coinGeckoPrices = await SharedCoinGeckoService.shared.fetchPrices(for: remainingTickers)
                
                // Merge CoinGecko prices
                for (ticker, priceData) in coinGeckoPrices {
                    prices[ticker] = priceData
                    updatedCount += 1
                }
                
                if !coinGeckoPrices.isEmpty {
                    source = "Hyperliquid + CoinGecko"
                }
            }
        }
        
        // Update asset prices
        for (ticker, priceData) in prices {
            if let index = assets.firstIndex(where: { $0.ticker.uppercased() == ticker.uppercased() }) {
                assets[index].price = priceData.price
                assets[index].priceChange24h = priceData.priceChange24h
                assets[index].priceChangePercent24h = priceData.priceChange24h
                assets[index].volume24h = priceData.volume24h
                
                // #region agent log
                DebugLogger.log(
                    location: "PearRepository.swift:fetchMarketPrices",
                    message: "Asset price updated",
                    data: [
                        "ticker": ticker,
                        "price": priceData.price,
                        "volume24h": priceData.volume24h,
                        "priceChange24h": priceData.priceChange24h,
                        "source": source
                    ],
                    hypothesisId: "PRICE-1"
                )
                // #endregion
            }
        }
        
        lastPriceUpdateTime = Date()
        print("🔵 [DEBUG] ✅ Prices fetched from \(source) - updated \(updatedCount)/\(assets.count) assets")
        
        if updatedCount < assets.count {
            let missingTickers = assets.filter { asset in
                !prices.keys.contains(where: { $0.uppercased() == asset.ticker.uppercased() })
            }.map { $0.ticker }
            print("🔵 [DEBUG] ⚠️ Missing prices for: \(missingTickers.joined(separator: ", "))")
        }
    }
    
    /// Extracts unique assets from active asset groups
    /// Creates Asset objects from longAssets and shortAssets across all groups
    private func extractUniqueAssets(from groups: [ActiveAssetGroupItem]) -> [Asset] {
        var assetMap: [String: Asset] = [:]
        
        // Collect all unique asset symbols from longAssets and shortAssets
        for group in groups {
            // Process long assets
            for pairAsset in group.longAssets {
                let symbol = pairAsset.asset.uppercased()
                if assetMap[symbol] == nil {
                    // Create a basic Asset object - price data will be updated from market data or WebSocket
                    assetMap[symbol] = Asset(
                        id: symbol,
                        ticker: symbol,
                        name: symbol, // Will be enhanced with actual name later
                        price: 0,
                        priceChange24h: 0,
                        priceChangePercent24h: 0,
                        volume24h: 0,
                        openInterest: nil,
                        maxLeverage: 1.0,
                        minOrderSize: 0,
                        tickSize: 0.01
                    )
                }
            }
            
            // Process short assets
            for pairAsset in group.shortAssets {
                let symbol = pairAsset.asset.uppercased()
                if assetMap[symbol] == nil {
                    assetMap[symbol] = Asset(
                        id: symbol,
                        ticker: symbol,
                        name: symbol,
                        price: 0,
                        priceChange24h: 0,
                        priceChangePercent24h: 0,
                        volume24h: 0,
                        openInterest: nil,
                        maxLeverage: 1.0,
                        minOrderSize: 0,
                        tickSize: 0.01
                    )
                }
            }
        }
        
        return Array(assetMap.values).sorted { $0.ticker < $1.ticker }
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
        print("🔵 [DEBUG] PriceUpdate received: assetId=\(update.assetId), price=\(update.price), volume=\(update.volume24h)")
        
        // #region agent log
        DebugLogger.log(
            location: "PearRepository.swift:164",
            message: "PriceUpdate received - checking for match",
            data: [
                "updateAssetId": update.assetId,
                "updateAssetIdLowercase": update.assetId.lowercased(),
                "price": update.price,
                "volume24h": update.volume24h,
                "availableAssetIds": assets.map { $0.id },
                "availableAssetIdsLowercase": assets.map { $0.id.lowercased() }
            ],
            hypothesisId: "PRICE-1"
        )
        // #endregion
        
        // Try exact match first
        if let index = assets.firstIndex(where: { $0.id == update.assetId }) {
            assets[index].price = update.price
            assets[index].priceChange24h = update.change24h
            assets[index].priceChangePercent24h = update.changePercent24h
            assets[index].volume24h = update.volume24h
            
            // #region agent log
            DebugLogger.log(
                location: "PearRepository.swift:177",
                message: "PriceUpdate matched - exact match",
                data: [
                    "assetId": update.assetId,
                    "ticker": assets[index].ticker,
                    "newPrice": update.price,
                    "matchType": "exact"
                ],
                hypothesisId: "PRICE-1"
            )
            // #endregion
            
            print("🔵 [DEBUG] ✅ Updated asset \(assets[index].ticker) price to \(update.price), volume to \(update.volume24h)")
            return
        }
        
        // Try case-insensitive match
        if let index = assets.firstIndex(where: { $0.id.lowercased() == update.assetId.lowercased() }) {
            assets[index].price = update.price
            assets[index].priceChange24h = update.change24h
            assets[index].priceChangePercent24h = update.changePercent24h
            assets[index].volume24h = update.volume24h
            
            // #region agent log
            DebugLogger.log(
                location: "PearRepository.swift:195",
                message: "PriceUpdate matched - case-insensitive",
                data: [
                    "updateAssetId": update.assetId,
                    "matchedAssetId": assets[index].id,
                    "ticker": assets[index].ticker,
                    "newPrice": update.price,
                    "matchType": "case-insensitive"
                ],
                hypothesisId: "PRICE-1"
            )
            // #endregion
            
            print("🔵 [DEBUG] ✅ Updated asset \(assets[index].ticker) price to \(update.price) (case-insensitive match)")
            return
        }
        
        // No match found
        print("🔵 [DEBUG] ⚠️ PriceUpdate for unknown asset: \(update.assetId)")
        print("🔵 [DEBUG] Available asset IDs: \(assets.map { $0.id }.joined(separator: ", "))")
        
        // #region agent log
        DebugLogger.log(
            location: "PearRepository.swift:210",
            message: "PriceUpdate NO MATCH - asset ID mismatch",
            data: [
                "updateAssetId": update.assetId,
                "updateAssetIdLowercase": update.assetId.lowercased(),
                "availableAssetIds": assets.map { $0.id },
                "availableAssetIdsLowercase": assets.map { $0.id.lowercased() },
                "price": update.price
            ],
            hypothesisId: "PRICE-1"
        )
        // #endregion
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
    
    // MARK: - Market Data
    /// Fetches market data from HTTP endpoint
    /// Market data may not require authentication - it's public market information
    func fetchMarketData() async {
        isLoadingMarketData = true
        lastError = nil
        
        print("🔵 [DEBUG] fetchMarketData() called")
        print("🔵 [DEBUG] API endpoint: \(Constants.API.baseURL)\(Constants.API.marketData)")
        
        do {
            let response = try await apiService.fetchMarketData()
            print("🔵 [DEBUG] ✅ fetchMarketData() succeeded")
            print("🔵 [DEBUG] Markets: \(response.markets.count)")
            print("🔵 [DEBUG] Funding rates: \(response.fundingRates.count)")
            print("🔵 [DEBUG] Total volume: \(response.dailyMetrics.totalVolume)")
            
            marketData = response
            
            // Subscribe to WebSocket market-data channel for real-time updates
            // This works even without auth token for public market data
            webSocketService.subscribeToMarketData()
            print("🔵 [DEBUG] ✅ Subscribed to WebSocket market-data channel")
            
        } catch {
            let errorMessage = error.localizedDescription
            print("🔵 [DEBUG] ❌ fetchMarketData() failed: \(errorMessage)")
            print("🔵 [DEBUG] Error type: \(type(of: error))")
            
            // Check if it's an authentication error
            if let afError = error as? AFError,
               let responseCode = afError.responseCode,
               responseCode == 401 {
                print("🔵 [DEBUG] ⚠️ Market data requires authentication")
                print("🔵 [DEBUG] This suggests market data endpoint needs auth token")
            } else {
                // For other errors, still try to subscribe to WebSocket
                // WebSocket might work even if HTTP fails
                webSocketService.subscribeToMarketData()
                print("🔵 [DEBUG] ⚠️ HTTP fetch failed, but subscribing to WebSocket anyway")
            }
            
            lastError = errorMessage
        }
        
        isLoadingMarketData = false
    }
    
    private func handleMarketDataUpdate(_ update: MarketDataUpdate) {
        print("🔵 [DEBUG] Received market data update from WebSocket")
        
        // MarketDataUpdate contains the full MarketDataResponse
        // Update our stored market data with the new data
        marketData = update.marketData
        
        // Update asset prices from market data if available
        for market in update.marketData.markets {
            if let assetIndex = assets.firstIndex(where: { $0.id == market.assetId }) {
                assets[assetIndex].price = market.price
                assets[assetIndex].priceChange24h = market.priceChange24h
                assets[assetIndex].priceChangePercent24h = market.priceChangePercent24h
                assets[assetIndex].volume24h = market.volume24h
            }
        }
        
        print("🔵 [DEBUG] Market data updated - \(update.marketData.markets.count) markets")
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

    private func updateAuthTokenIfPresent(_ token: String?) async {
        guard let token, !token.isEmpty else { return }
        await AuthService.shared.updateAuthToken(token)
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
    
    // MARK: - Debug Helper
    /// Reloads agent wallet from keychain (for debug bypass)
    func reloadAgentWalletFromKeychain() {
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
        print("[Repo] ========================================")
        print("[Repo] createAgentWallet() - ENTRY POINT")
        print("[Repo] ========================================")
        
        guard let userAddress = walletService.connectedAddress else {
            print("[Repo] ❌ ERROR: connectedAddress is NIL!")
            // #region agent log
            print("🟡 [HYPO-B] WalletRepository.createAgentWallet - connectedAddress is NIL!")
            // #endregion
            throw WalletError.notConnected
        }
        
        print("[Repo] Input parameters:")
        print("[Repo]   - userAddress: \(userAddress)")
        print("[Repo]   - hasAuthToken: \(KeychainService.shared.authToken != nil)")
        print("[Repo]   - authTokenLength: \(KeychainService.shared.authToken?.count ?? 0)")
        
        isLoading = true
        error = nil
        
        defer { 
            isLoading = false
            print("[Repo] Defer: isLoading set to false")
        }
        
        // #region agent log
        print("🟡 [HYPO-A,C] WalletRepository calling API - userAddress: \(userAddress), hasAuthToken: \(KeychainService.shared.authToken != nil)")
        // #endregion
        
        let request = AgentWalletCreateRequest(userWalletAddress: userAddress)
        print("[Repo] Request object created:")
        print("[Repo]   - userWalletAddress: \(request.userWalletAddress)")
        
        print("[Repo] Before calling API service...")
        print("[Repo] About to call apiService.createAgentWallet(request: request)")
        
        do {
            let response = try await apiService.createAgentWallet(request: request)
            
            print("[Repo] ========================================")
            print("[Repo] API call SUCCESS")
            print("[Repo] ========================================")
            print("[Repo] Response received:")
            print("[Repo]   - agentWalletAddress: \(response.agentWalletAddress)")
            print("[Repo]   - messageToSign length: \(response.messageToSign.count)")
            print("[Repo]   - expiresAt: \(response.expiresAt?.description ?? "nil")")
            print("[Repo]   - nonce: \(response.nonce ?? "nil")")
            print("[Repo]   - hasResolvedAuthToken: \(response.resolvedAuthToken != nil)")
            
            // #region agent log
            print("🟡 [HYPO-C,D] WalletRepository API SUCCESS - agentWalletAddress: \(response.agentWalletAddress)")
            // #endregion
            
            print("[Repo] Updating auth token if present...")
            await updateAuthTokenIfPresent(response.resolvedAuthToken)
            print("[Repo] Auth token update completed")
            
            print("[Repo] ========================================")
            print("[Repo] createAgentWallet() - SUCCESS EXIT")
            print("[Repo] ========================================")
            
            return response
        } catch {
            print("[Repo] ========================================")
            print("[Repo] API call FAILED")
            print("[Repo] ========================================")
            print("[Repo] Error type: \(type(of: error))")
            print("[Repo] Error description: \(error.localizedDescription)")
            print("[Repo] Full error: \(error)")
            
            if let afError = error as? AFError {
                print("[Repo] AFError details:")
                print("[Repo]   - responseCode: \(afError.responseCode?.description ?? "nil")")
                print("[Repo]   - underlyingError: \(afError.underlyingError?.localizedDescription ?? "nil")")
            }
            
            print("[Repo] Re-throwing error...")
            throw error
        }
    }
    
    func approveAgentWallet(signature: String, agentWalletAddress: String) async throws {
        guard walletService.connectedAddress != nil else {
            throw WalletError.notConnected
        }
        
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // #region agent log
        print("🟡 [HYPO-APPROVE] ========================================")
        print("🟡 [HYPO-APPROVE] approveAgentWallet - Repository")
        print("🟡 [HYPO-APPROVE] ========================================")
        print("🟡 [HYPO-APPROVE] NOTE: /agentWallet/approve endpoint does not exist on server")
        print("🟡 [HYPO-APPROVE] The API message 'Please approve on Hyperliquid Exchange' is instructional")
        print("🟡 [HYPO-APPROVE] Storing agent wallet directly as a workaround")
        // #endregion
        
        // WORKAROUND: The /agentWallet/approve endpoint doesn't exist on the server.
        // The server's message "Please approve this agent wallet on Hyperliquid Exchange"
        // is informational only. For the hackathon, we store the wallet directly.
        // In production, this would need proper Hyperliquid exchange integration.
        
        // Create a local agent wallet record
        let now = Date()
        let expiryDate = now.addingTimeInterval(Double(Constants.AgentWallet.expiryDays) * 24 * 60 * 60)
        
        let wallet = AgentWallet(
            address: agentWalletAddress,
            createdAt: now,
            expiresAt: expiryDate,
            isApproved: true, // Mark as approved for hackathon flow
            approvalSignature: signature
        )
        
        agentWallet = wallet
        keychainService.agentWalletAddress = wallet.address
        keychainService.agentWalletExpiry = wallet.expiresAt
        keychainService.pendingAgentWalletAddress = nil
        keychainService.pendingAgentWalletMessage = nil
        keychainService.pendingAgentWalletExpiry = nil
        keychainService.pendingAgentUserWalletAddress = nil
        
        print("🟡 [HYPO-APPROVE] ✅ Agent wallet stored successfully")
        print("🟡 [HYPO-APPROVE]   - address: \(wallet.address)")
        print("🟡 [HYPO-APPROVE]   - expiresAt: \(wallet.expiresAt)")
        print("🟡 [HYPO-APPROVE]   - isApproved: \(wallet.isApproved)")
    }
    
    func checkAgentWalletStatus() async {
        guard let userAddress = walletService.connectedAddress else { return }
        
        do {
            let response = try await apiService.getAgentWalletStatus(userAddress: userAddress)
            await updateAuthTokenIfPresent(response.resolvedAuthToken)
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
