import SwiftUI

// MARK: - Position Detail View
struct PositionDetailView: View {
    let position: Position
    @ObservedObject var viewModel: PositionsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        PositionDetailHeader(position: position)
                        
                        // PnL Summary
                        PnLSummaryCard(position: position)
                        
                        // Legs
                        PositionLegsSection(legs: position.legs)
                        
                        // Trade Info
                        TradeInfoSection(position: position)
                        
                        // TP/SL
                        if position.takeProfitPercent != nil || position.stopLossPercent != nil {
                            TakeProfitStopLossInfoSection(position: position)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                
                // Close Button
                VStack {
                    Spacer()
                    
                    ClosePositionBar(
                        isLoading: viewModel.isClosingPosition,
                        onClose: {
                            viewModel.prepareClosePosition(position)
                        }
                    )
                }
            }
            .navigationTitle(position.basketName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.pearPrimary)
                }
            }
        }
    }
}

// MARK: - Position Detail Header
struct PositionDetailHeader: View {
    let position: Position
    
    var body: some View {
        VStack(spacing: 8) {
            // Status badge
            HStack(spacing: 6) {
                Circle()
                    .fill(position.status == .open ? Color.pearProfit : Color.secondary)
                    .frame(width: 8, height: 8)
                
                Text(position.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.backgroundSecondary)
            .cornerRadius(20)
            
            // Time open
            Text("Open for \(position.timeOpen)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - PnL Summary Card
struct PnLSummaryCard: View {
    let position: Position
    
    var body: some View {
        VStack(spacing: 20) {
            // Main PnL
            VStack(spacing: 4) {
                Text("Unrealized P&L")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(position.formattedPnL)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color.pnlColor(for: position.totalPnL))
                
                Text(position.formattedPnLPercent)
                    .font(.headline)
                    .foregroundColor(Color.pnlColor(for: position.totalPnL))
            }
            
            Divider()
            
            // Value comparison
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("Entry Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(position.formattedEntryValue)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                VStack(spacing: 4) {
                    Text("Current Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(position.formattedCurrentValue)
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

// MARK: - Position Legs Section
struct PositionLegsSection: View {
    let legs: [PositionLeg]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basket Legs")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                ForEach(legs) { leg in
                    PositionLegRow(leg: leg)
                    
                    if leg.id != legs.last?.id {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Position Leg Row
struct PositionLegRow: View {
    let leg: PositionLeg
    
    var body: some View {
        HStack(spacing: 12) {
            AssetIcon(ticker: leg.assetTicker, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(leg.assetTicker)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    DirectionBadge(direction: leg.direction)
                }
                
                HStack(spacing: 12) {
                    Text("Entry: \(leg.formattedEntryPrice)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Now: \(leg.formattedCurrentPrice)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(leg.formattedPnL)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.pnlColor(for: leg.unrealizedPnL))
                
                Text(leg.formattedPnLPercent)
                    .font(.caption)
                    .foregroundColor(Color.pnlColor(for: leg.unrealizedPnL))
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Trade Info Section
struct TradeInfoSection: View {
    let position: Position
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trade Info")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                InfoRow(label: "Margin Used", value: position.marginUsed.asCurrency)
                InfoRow(label: "Leverage", value: "\(Int(position.leverage))x")
                InfoRow(label: "Funding Fees", value: position.fundingFees.asCurrency)
                InfoRow(label: "Opened", value: formatDate(position.openedAt))
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Take Profit Stop Loss Info Section
struct TakeProfitStopLossInfoSection: View {
    let position: Position
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risk Management")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                if let tp = position.takeProfitPercent {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Take Profit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("+\(tp)%")
                            .font(.headline)
                            .foregroundColor(.pearProfit)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.pearProfit.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if let sl = position.stopLossPercent {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stop Loss")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("-\(sl)%")
                            .font(.headline)
                            .foregroundColor(.pearLoss)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.pearLoss.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Close Position Bar
struct ClosePositionBar: View {
    var isLoading: Bool
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            PrimaryButton(
                title: "Close Position",
                isLoading: isLoading,
                style: .destructive
            ) {
                onClose()
            }
            .padding()
        }
        .background(Color.backgroundSecondary)
    }
}

#Preview {
    PositionDetailView(
        position: Position.sample,
        viewModel: PositionsViewModel()
    )
}
