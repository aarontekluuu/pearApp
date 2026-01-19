import SwiftUI

// MARK: - Trade Review View
struct TradeReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: BasketBuilderViewModel
    
    @State private var confirmationProgress: CGFloat = 0
    @State private var isConfirming = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            TradeReviewHeader(basket: viewModel.basket)
                            
                            // Basket Legs
                            TradeReviewLegsSection(legs: viewModel.basket.legs)
                            
                            // Trade Details
                            TradeReviewDetailsSection(viewModel: viewModel)
                            
                            // Warnings
                            TradeWarningsSection()
                        }
                        .padding()
                        .padding(.bottom, 100) // Extra padding for button
                    }
                    
                    // Swipe to Confirm - Fixed at bottom
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color.divider)
                        
                        SwipeToConfirmButton(
                            title: "Swipe to Execute",
                            isLoading: viewModel.isExecuting,
                            onConfirm: {
                                Task {
                                    await viewModel.executeTrade()
                                }
                            }
                        )
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 34) // 16pt padding + 18pt for tab bar clearance
                    }
                    .background(Color.backgroundPrimary)
                }
            }
            .navigationTitle("Review Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isExecuting)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Trade Review Header
struct TradeReviewHeader: View {
    let basket: Basket
    
    var body: some View {
        VStack(spacing: 12) {
            Image("pear")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
            
            Text(basket.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("\(basket.legs.count) asset\(basket.legs.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Trade Review Legs Section
struct TradeReviewLegsSection: View {
    let legs: [BasketLeg]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basket Composition")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 8) {
                ForEach(legs) { leg in
                    HStack {
                        AssetIcon(ticker: leg.asset.ticker, size: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(leg.asset.ticker)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.textPrimary)
                            
                            Text(leg.asset.formattedPrice)
                                .font(.caption)
                                .foregroundColor(.textTertiary)
                        }
                        
                        Spacer()
                        
                        DirectionBadge(direction: leg.direction)
                        
                        Text(leg.formattedWeight)
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    
                    if leg.id != legs.last?.id {
                        Divider()
                            .background(Color.borderSubtle)
                    }
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Trade Review Details Section
struct TradeReviewDetailsSection: View {
    @ObservedObject var viewModel: BasketBuilderViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trade Details")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 16) {
                DetailRow(label: "Position Size", value: viewModel.positionSizeValue.asCurrency)
                DetailRow(label: "Margin Required", value: viewModel.marginRequired.asCurrency)
                
                Divider()
                    .background(Color.borderSubtle)
                
                DetailRow(label: "Trading Fee", value: "~\(viewModel.estimatedFees.asCurrency)", labelOpacity: 0.5)
                DetailRow(label: "Network", value: "Arbitrum", labelOpacity: 0.5)
                
                if let tp = viewModel.basket.takeProfitPercent {
                    Divider()
                        .background(Color.borderSubtle)
                    DetailRow(
                        label: "Take Profit",
                        value: "+\(tp)%",
                        valueColor: .pearProfit
                    )
                }
                
                if let sl = viewModel.basket.stopLossPercent {
                    DetailRow(
                        label: "Stop Loss",
                        value: "-\(sl)%",
                        valueColor: .pearLoss
                    )
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .textPrimary
    var labelOpacity: Double = 0.6
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(labelOpacity))
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Trade Warnings Section
struct TradeWarningsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.pearWarning.opacity(0.8))
                
                Text("Trading perpetual futures involves significant risk")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue.opacity(0.7))
                
                Text("Prices are subject to slippage during execution")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Swipe to Confirm Button
struct SwipeToConfirmButton: View {
    let title: String
    var isLoading: Bool = false
    let onConfirm: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    @State private var lastTickProgress: CGFloat = 0
    
    private let threshold: CGFloat = 0.7
    
    var progress: CGFloat {
        min(1, max(0, offset / (width * threshold)))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.backgroundSecondary)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primaryGradient)
                    .frame(width: offset + 60)
                
                // Text
                HStack {
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white.opacity(1 - progress))
                    }
                    
                    Spacer()
                }
                
                // Slider thumb
                if !isLoading {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: progress >= 1 ? "checkmark" : "chevron.right.2")
                                .font(.headline)
                                .foregroundColor(.pearPrimary)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .offset(x: offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = max(0, min(value.translation.width, width - 60))
                                    offset = newOffset
                                    
                                    // Haptic feedback at progress milestones
                                    let currentProgress = min(1, max(0, newOffset / (width * threshold)))
                                    if currentProgress - lastTickProgress > 0.25 {
                                        HapticManager.shared.sliderTick()
                                        lastTickProgress = currentProgress
                                    }
                                }
                                .onEnded { _ in
                                    if progress >= 1 {
                                        HapticManager.shared.swipeComplete()
                                        onConfirm()
                                    } else {
                                        HapticManager.shared.softTap()
                                        withAnimation(.spring()) {
                                            offset = 0
                                        }
                                    }
                                    lastTickProgress = 0
                                }
                        )
                        .padding(4)
                }
            }
            .frame(height: 60)
            .onAppear {
                width = geometry.size.width
            }
        }
        .frame(height: 60)
        .disabled(isLoading)
    }
}

// MARK: - Trade Execution Success View
struct TradeExecutionSuccessView: View {
    let response: TradeExecuteResponse
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.pearProfit)
            
            VStack(spacing: 8) {
                Text("Trade Executed!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("Your basket position is now open")
                    .font(.subheadline)
                    .foregroundColor(.textTertiary)
            }
            
            // Order details
            VStack(spacing: 12) {
                HStack {
                    Text("Order ID")
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text(response.orderId.truncatedTxHash)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.textSecondary)
                }
                
                HStack {
                    Text("Total Fees")
                        .foregroundColor(.textTertiary)
                    Spacer()
                    Text(response.totalFees.asCurrency)
                        .foregroundColor(.textPrimary)
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
            
            Spacer()
            
            PrimaryButton(title: "View Position") {
                onDismiss()
            }
        }
        .padding()
        .background(Color.backgroundPrimary)
        .onAppear {
            HapticManager.shared.tradeSuccess()
        }
    }
}
