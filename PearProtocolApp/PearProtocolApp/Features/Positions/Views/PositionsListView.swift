import SwiftUI

// MARK: - Positions List View
struct PositionsListView: View {
    @StateObject private var viewModel = PositionsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Portfolio Summary
                    PortfolioSummaryCard(viewModel: viewModel)
                        .padding()
                    
                    // Tab Selector
                    PositionsTabSelector(selectedTab: $viewModel.selectedTab)
                        .padding(.horizontal)
                    
                    // Content
                    Group {
                        switch viewModel.selectedTab {
                        case .open:
                            OpenPositionsContent(viewModel: viewModel)
                        case .history:
                            TradeHistoryContent(viewModel: viewModel)
                        }
                    }
                }
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.pearPrimary)
                    }
                    .disabled(viewModel.isRefreshing)
                }
            }
            .sheet(isPresented: $viewModel.showPositionDetail) {
                if let position = viewModel.selectedPosition {
                    PositionDetailView(
                        position: position,
                        viewModel: viewModel
                    )
                }
            }
            .alert("Close Position", isPresented: $viewModel.showCloseConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Close", role: .destructive) {
                    if let position = viewModel.selectedPosition {
                        Task {
                            await viewModel.closePosition(position)
                        }
                    }
                }
            } message: {
                if let position = viewModel.selectedPosition {
                    Text("Are you sure you want to close \(position.basketName)?")
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.error ?? "An unexpected error occurred")
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Portfolio Summary Card
struct PortfolioSummaryCard: View {
    @ObservedObject var viewModel: PositionsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Total Value
            VStack(spacing: 4) {
                Text("Portfolio Value")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(viewModel.totalPortfolioValue.asCurrency)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // PnL
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Unrealized P&L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.totalUnrealizedPnL.asCurrencyWithSign)
                        .font(.headline)
                        .foregroundColor(Color.pnlColor(for: viewModel.totalUnrealizedPnL))
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(spacing: 4) {
                    Text("Margin Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.totalMarginUsed.asCurrency)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(spacing: 4) {
                    Text("Positions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(viewModel.openPositions.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }
}

// MARK: - Positions Tab Selector
struct PositionsTabSelector: View {
    @Binding var selectedTab: PositionsTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PositionsTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .pearPrimary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.pearPrimary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Open Positions Content
struct OpenPositionsContent: View {
    @ObservedObject var viewModel: PositionsViewModel
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.positions.isEmpty {
                LoadingView(message: "Loading positions...")
            } else if viewModel.openPositions.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No Open Positions",
                    message: "You don't have any open positions yet",
                    actionTitle: "Create Basket"
                ) {
                    // Navigate to build tab
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.openPositions) { position in
                            PositionCard(position: position)
                                .onTapGesture {
                                    viewModel.selectPosition(position)
                                }
                                .contextMenu {
                                    Button(action: {
                                        viewModel.selectPosition(position)
                                    }) {
                                        Label("View Details", systemImage: "eye")
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        viewModel.prepareClosePosition(position)
                                    }) {
                                        Label("Close Position", systemImage: "xmark.circle")
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
    }
}

// MARK: - Position Card
struct PositionCard: View {
    let position: Position
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.basketName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(position.legs.count) leg\(position.legs.count == 1 ? "" : "s") · \(position.timeOpen)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // PnL
                VStack(alignment: .trailing, spacing: 4) {
                    Text(position.formattedPnL)
                        .font(.headline)
                        .foregroundColor(Color.pnlColor(for: position.totalPnL))
                    
                    Text(position.formattedPnLPercent)
                        .font(.caption)
                        .foregroundColor(Color.pnlColor(for: position.totalPnL))
                }
            }
            
            Divider()
            
            // Legs preview
            HStack(spacing: 8) {
                ForEach(position.legs.prefix(3)) { leg in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.directionColor(isLong: leg.direction == .long))
                            .frame(width: 6, height: 6)
                        
                        Text(leg.assetTicker)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if position.legs.count > 3 {
                    Text("+\(position.legs.count - 3)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Entry value
                Text(position.formattedEntryValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }
}

// MARK: - Trade History Content
struct TradeHistoryContent: View {
    @ObservedObject var viewModel: PositionsViewModel
    
    var body: some View {
        Group {
            if viewModel.tradeHistory.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No Trade History",
                    message: "Your closed trades will appear here"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.tradeHistory) { trade in
                            TradeHistoryCard(trade: trade)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Trade History Card
struct TradeHistoryCard: View {
    let trade: TradeHistoryItem
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trade.basketName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(trade.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(trade.realizedPnL.asCurrencyWithSign)
                        .font(.headline)
                        .foregroundColor(trade.isProfitable ? .pearProfit : .pearLoss)
                    
                    Text(trade.realizedPnLPercent.asPercentageWithSign)
                        .font(.caption)
                        .foregroundColor(trade.isProfitable ? .pearProfit : .pearLoss)
                }
            }
            
            HStack {
                Text("Entry: \(trade.entryValue.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Exit: \(trade.exitValue.asCurrency)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

#Preview {
    PositionsListView()
}
