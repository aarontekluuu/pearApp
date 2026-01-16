import SwiftUI

// MARK: - Asset Row
struct AssetRow: View {
    let asset: Asset
    var showAddButton: Bool = false
    var onAdd: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Asset icon
            AssetIcon(ticker: asset.ticker)
            
            // Asset info
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.ticker)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(asset.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Price info
            VStack(alignment: .trailing, spacing: 4) {
                Text(asset.formattedPrice)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(asset.formattedChange)
                    .font(.caption)
                    .foregroundColor(asset.isPriceUp ? .pearProfit : .pearLoss)
            }
            
            // Add button
            if showAddButton {
                Button(action: {
                    triggerHaptic()
                    onAdd?()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.pearPrimary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Asset Icon
struct AssetIcon: View {
    let ticker: String
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            Circle()
                .fill(colorForTicker(ticker))
            
            Text(String(ticker.prefix(2)))
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
    
    private func colorForTicker(_ ticker: String) -> Color {
        // Generate consistent colors based on ticker
        let colors: [Color] = [
            Color(red: 0.95, green: 0.62, blue: 0.07),  // Bitcoin orange
            Color(red: 0.38, green: 0.38, blue: 0.65),  // Ethereum purple
            Color(red: 0.00, green: 0.84, blue: 0.63),  // Tether green
            Color(red: 0.96, green: 0.76, blue: 0.07),  // Gold
            Color(red: 0.36, green: 0.49, blue: 0.98),  // Blue
            Color(red: 0.67, green: 0.33, blue: 0.86),  // Purple
        ]
        
        let hash = ticker.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[hash % colors.count]
    }
}

// MARK: - Compact Asset Row (for basket legs)
struct CompactAssetRow: View {
    let asset: Asset
    let direction: TradeDirection
    let weight: Double
    var onRemove: (() -> Void)? = nil
    var onToggleDirection: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Asset icon
            AssetIcon(ticker: asset.ticker, size: 36)
            
            // Asset info
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.ticker)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(asset.formattedPrice)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Direction badge
            DirectionBadge(direction: direction, onTap: onToggleDirection)
            
            // Weight
            Text(weight.asWeight)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 50, alignment: .trailing)
            
            // Remove button
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Direction Badge
struct DirectionBadge: View {
    let direction: TradeDirection
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            triggerHaptic()
            onTap?()
        }) {
            HStack(spacing: 4) {
                Image(systemName: direction.icon)
                    .font(.caption)
                
                Text(direction.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.directionColor(isLong: direction == .long).opacity(0.2))
            .foregroundColor(Color.directionColor(isLong: direction == .long))
            .cornerRadius(8)
        }
        .disabled(onTap == nil)
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Selectable Asset Row
struct SelectableAssetRow: View {
    let asset: Asset
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            triggerHaptic()
            onSelect()
        }) {
            HStack(spacing: 12) {
                AssetIcon(ticker: asset.ticker)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.ticker)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(asset.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Vol: \(asset.formattedVolume)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(asset.formattedPrice)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(asset.formattedChange)
                        .font(.caption)
                        .foregroundColor(asset.isPriceUp ? .pearProfit : .pearLoss)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .pearPrimary : .secondary)
                    .font(.title3)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isSelected ? Color.pearPrimary.opacity(0.1) : Color.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.pearPrimary : Color.clear, lineWidth: 1)
            )
        }
    }
    
    private func triggerHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

#Preview {
    VStack(spacing: 16) {
        AssetRow(asset: Asset.sample, showAddButton: true) {
            print("Add")
        }
        
        CompactAssetRow(
            asset: Asset.sample,
            direction: .long,
            weight: 50,
            onRemove: { print("Remove") },
            onToggleDirection: { print("Toggle") }
        )
        .padding(.horizontal)
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
        
        SelectableAssetRow(
            asset: Asset.sample,
            isSelected: true,
            onSelect: { print("Select") }
        )
        
        HStack(spacing: 12) {
            DirectionBadge(direction: .long)
            DirectionBadge(direction: .short)
        }
    }
    .padding()
    .background(Color.backgroundPrimary)
}
