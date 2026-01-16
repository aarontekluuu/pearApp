import Foundation
import SwiftUI
import Combine

// MARK: - Positions ViewModel
@MainActor
final class PositionsViewModel: ObservableObject {
    // MARK: - Published State
    @Published var positions: [Position] = []
    @Published var tradeHistory: [TradeHistoryItem] = []
    @Published var selectedPosition: Position?
    @Published var showPositionDetail = false
    @Published var showCloseConfirmation = false
    
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isClosingPosition = false
    @Published var error: String?
    @Published var showError = false
    
    @Published var selectedTab: PositionsTab = .open
    
    // MARK: - Dependencies
    private let repository = PearRepository.shared
    private let walletRepository = WalletRepository.shared
    private let apiService = PearAPIService.shared
    private let webSocketService = WebSocketService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var totalUnrealizedPnL: Double {
        positions.reduce(0) { $0 + $1.unrealizedPnL }
    }
    
    var totalPortfolioValue: Double {
        positions.reduce(0) { $0 + $1.currentValue }
    }
    
    var totalMarginUsed: Double {
        positions.reduce(0) { $0 + $1.marginUsed }
    }
    
    var openPositions: [Position] {
        positions.filter { $0.status == .open }
    }
    
    var hasOpenPositions: Bool {
        !openPositions.isEmpty
    }
    
    // MARK: - Init
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Sync with repository
        repository.$positions
            .receive(on: DispatchQueue.main)
            .assign(to: &$positions)
        
        repository.$tradeHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$tradeHistory)
        
        repository.$isLoadingPositions
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        // Position updates via WebSocket
        webSocketService.positionUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handlePositionUpdate(update)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func loadData() async {
        guard let agentWallet = walletRepository.agentWallet else {
            error = "Agent wallet not configured"
            return
        }
        
        await repository.fetchPositions(agentWalletAddress: agentWallet.address)
        await repository.fetchTradeHistory(agentWalletAddress: agentWallet.address)
    }
    
    func refresh() async {
        isRefreshing = true
        await loadData()
        isRefreshing = false
    }
    
    // MARK: - Position Updates
    private func handlePositionUpdate(_ update: PositionUpdate) {
        guard let index = positions.firstIndex(where: { $0.id == update.positionId }) else { return }
        
        positions[index].currentValue = update.currentValue
        positions[index].unrealizedPnL = update.unrealizedPnL
        positions[index].unrealizedPnLPercent = update.unrealizedPnLPercent
    }
    
    // MARK: - Position Actions
    func selectPosition(_ position: Position) {
        selectedPosition = position
        showPositionDetail = true
    }
    
    func prepareClosePosition(_ position: Position) {
        selectedPosition = position
        showCloseConfirmation = true
    }
    
    func closePosition(_ position: Position, percentage: Double = 100) async {
        guard let agentWallet = walletRepository.agentWallet else {
            error = "Agent wallet not configured"
            showError = true
            return
        }
        
        isClosingPosition = true
        error = nil
        
        do {
            let request = ClosePositionRequest(
                positionId: position.id,
                agentWalletAddress: agentWallet.address,
                percentage: percentage
            )
            
            let response = try await apiService.closePosition(request: request)
            
            if response.status.isSuccess {
                // Remove from local state
                positions.removeAll { $0.id == position.id }
                
                // Refresh data
                await loadData()
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                error = response.message ?? "Failed to close position"
                showError = true
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        } catch {
            self.error = error.localizedDescription
            showError = true
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isClosingPosition = false
        showCloseConfirmation = false
        selectedPosition = nil
    }
    
    func dismissError() {
        showError = false
        error = nil
    }
}

// MARK: - Positions Tab
enum PositionsTab: String, CaseIterable {
    case open = "Open"
    case history = "History"
    
    var icon: String {
        switch self {
        case .open: return "chart.bar.fill"
        case .history: return "clock.fill"
        }
    }
}

// MARK: - Close Position Use Case
actor ClosePositionUseCase {
    private let apiService = PearAPIService.shared
    
    func execute(positionId: String, agentWalletAddress: String, percentage: Double = 100) async throws -> ClosePositionResponse {
        let request = ClosePositionRequest(
            positionId: positionId,
            agentWalletAddress: agentWalletAddress,
            percentage: percentage
        )
        
        return try await apiService.closePosition(request: request)
    }
}
