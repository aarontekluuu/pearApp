import Foundation
import SwiftUI
import Combine

// MARK: - Basket Builder ViewModel
@MainActor
final class BasketBuilderViewModel: ObservableObject {
    // MARK: - Published State
    @Published var basket: Basket = Basket()
    @Published var positionSize: String = ""
    @Published var takeProfitPercent: String = ""
    @Published var stopLossPercent: String = ""
    
    @Published var showAssetSearch = false
    @Published var showTradeReview = false
    @Published var isExecuting = false
    @Published var executionError: String?
    @Published var showError = false
    @Published var lastExecutedTrade: TradeExecuteResponse?
    
    // MARK: - Dependencies
    private let repository = PearRepository.shared
    private let walletRepository = WalletRepository.shared
    private let apiService = PearAPIService.shared
    private let webSocketService = WebSocketService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var positionSizeValue: Double {
        Double(positionSize) ?? 0
    }
    
    var isValidPositionSize: Bool {
        positionSizeValue >= Constants.Trading.minPositionSize
    }
    
    var canExecuteTrade: Bool {
        basket.isValid && isValidPositionSize
    }
    
    var validationErrors: [String] {
        var errors = basket.validationErrors
        
        if !positionSize.isEmpty && !isValidPositionSize {
            errors.append("Minimum position size is $\(Int(Constants.Trading.minPositionSize))")
        }
        
        return errors
    }
    
    var marginRequired: Double {
        positionSizeValue / Constants.Trading.defaultLeverage
    }
    
    var estimatedFees: Double {
        positionSizeValue * Constants.Trading.builderFeePercentage
    }
    
    var legsDescription: String {
        if basket.legs.isEmpty {
            return "No assets selected"
        }
        return basket.legs.map { "\($0.asset.ticker) \($0.direction.displayName)" }.joined(separator: ", ")
    }
    
    // MARK: - Init
    init() {
        setupPriceSubscription()
    }
    
    private func setupPriceSubscription() {
        webSocketService.priceUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.updateAssetPrice(update)
            }
            .store(in: &cancellables)
    }
    
    private func updateAssetPrice(_ update: PriceUpdate) {
        guard let index = basket.legs.firstIndex(where: { $0.asset.id == update.assetId }) else { return }
        basket.legs[index].asset.price = update.price
        basket.legs[index].asset.priceChange24h = update.change24h
        basket.legs[index].asset.priceChangePercent24h = update.changePercent24h
    }
    
    // MARK: - Basket Management
    func addAssets(_ assets: [Asset]) {
        for asset in assets {
            basket.addLeg(asset: asset)
        }
        
        // Subscribe to price updates
        let assetIds = assets.map { $0.id }
        webSocketService.subscribeToPrices(assets: assetIds)
    }
    
    func removeLeg(at index: Int) {
        let assetId = basket.legs[index].asset.id
        basket.removeLeg(at: index)
        webSocketService.unsubscribeFromPrices(assets: [assetId])
    }
    
    func toggleDirection(at index: Int) {
        basket.toggleLegDirection(at: index)
    }
    
    func updateWeight(at index: Int, weight: Double) {
        basket.updateLegWeight(at: index, weight: weight)
    }
    
    func equalizeWeights() {
        basket.equalizeWeights()
    }
    
    func setBasketName(_ name: String) {
        basket.name = name
    }
    
    // MARK: - Trade Execution
    func prepareTrade() {
        basket.totalSize = positionSizeValue
        
        if let tp = Double(takeProfitPercent), tp > 0 {
            basket.takeProfitPercent = tp
        }
        
        if let sl = Double(stopLossPercent), sl > 0 {
            basket.stopLossPercent = sl
        }
        
        showTradeReview = true
    }
    
    func executeTrade() async {
        guard let agentWallet = walletRepository.agentWallet else {
            executionError = "Agent wallet not configured"
            showError = true
            return
        }
        
        isExecuting = true
        executionError = nil
        
        do {
            let request = TradeExecuteRequest(
                basket: basket,
                agentWalletAddress: agentWallet.address
            )
            
            let response = try await apiService.executeTrade(request: request)
            
            if response.status.isSuccess {
                lastExecutedTrade = response
                
                // Trigger success haptic
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Reset basket after successful trade
                resetBasket()
            } else {
                executionError = response.message ?? "Trade execution failed"
                showError = true
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        } catch {
            executionError = error.localizedDescription
            showError = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isExecuting = false
        showTradeReview = false
    }
    
    func resetBasket() {
        basket = Basket()
        positionSize = ""
        takeProfitPercent = ""
        stopLossPercent = ""
        lastExecutedTrade = nil
    }
    
    func dismissError() {
        showError = false
        executionError = nil
    }
}

// MARK: - Presets
extension BasketBuilderViewModel {
    struct BasketPreset {
        let name: String
        let description: String
        let longAssets: [String]
        let shortAssets: [String]
    }
    
    static let presets: [BasketPreset] = [
        BasketPreset(
            name: "BTC/ETH Ratio",
            description: "Long BTC, Short ETH - bet on BTC outperformance",
            longAssets: ["BTC"],
            shortAssets: ["ETH"]
        ),
        BasketPreset(
            name: "AI vs Traditional Tech",
            description: "Long NVDA, Short AAPL - AI momentum play",
            longAssets: ["NVDA"],
            shortAssets: ["AAPL"]
        ),
        BasketPreset(
            name: "Crypto Momentum",
            description: "Long SOL + AVAX, Short ETH",
            longAssets: ["SOL", "AVAX"],
            shortAssets: ["ETH"]
        )
    ]
    
    func applyPreset(_ preset: BasketPreset, availableAssets: [Asset]) {
        resetBasket()
        basket.name = preset.name
        
        for longTicker in preset.longAssets {
            if let asset = availableAssets.first(where: { $0.ticker == longTicker }) {
                basket.addLeg(asset: asset, direction: .long)
            }
        }
        
        for shortTicker in preset.shortAssets {
            if let asset = availableAssets.first(where: { $0.ticker == shortTicker }) {
                basket.addLeg(asset: asset, direction: .short)
            }
        }
        
        basket.equalizeWeights()
    }
}
