import SwiftUI

// MARK: - Asset Row
struct AssetRow: View {
    let asset: Asset
    var showAddButton: Bool = false
    var onAdd: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: Constants.UI.spacingSM + 4) {
            // Asset icon
            AssetIcon(ticker: asset.ticker)
            
            // Asset info
            VStack(alignment: .leading, spacing: Constants.UI.spacingXS) {
                Text(asset.ticker)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(asset.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Price info
            VStack(alignment: .trailing, spacing: Constants.UI.spacingXS) {
                Text(asset.formattedPrice)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(asset.formattedChange)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(asset.isPriceUp ? .pearProfit : .pearLoss)
            }
            
            // Add button
            if showAddButton {
                Button(action: {
                    triggerHaptic()
                    onAdd?()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.pearPrimary)
                }
            }
        }
        .padding(.vertical, Constants.UI.spacingSM + 4)
        .padding(.horizontal, Constants.UI.cardPadding)
        .background(Color.backgroundSecondary)
        .cornerRadius(Constants.UI.cornerRadius)
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Asset Icon
struct AssetIcon: View {
    let ticker: String
    var size: CGFloat = Constants.UI.iconSizeLarge
    
    @State private var iconImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let iconImage = iconImage {
                Image(uiImage: iconImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
            } else {
                // Fallback to colored circle with initials
                ZStack {
                    Circle()
                        .fill(colorForTicker(ticker))
                    
                    Text(String(ticker.prefix(2)))
                        .font(.system(size: size * 0.35, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            loadIcon()
        }
    }
    
    private func loadIcon() {
        guard !isLoading else { return }
        
        let normalizedTicker = ticker.uppercased()
        
        // Check cache first
        if let cached = SharedCoinGeckoService.shared.getCachedIcon(for: normalizedTicker) {
            self.iconImage = cached
            return
        }
        
        isLoading = true
        
        Task {
            if let image = await SharedCoinGeckoService.shared.fetchIcon(for: normalizedTicker) {
                await MainActor.run {
                    self.iconImage = image
                }
            }
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func colorForTicker(_ ticker: String) -> Color {
        // Generate consistent colors based on ticker
        let colors: [Color] = [
            Color(hex: "F39C12"),  // Bitcoin orange
            Color(hex: "6366F1"),  // Ethereum purple
            Color(hex: "10B981"),  // Tether green
            Color(hex: "F59E0B"),  // Gold
            Color(hex: "3B82F6"),  // Blue
            Color(hex: "8B5CF6"),  // Purple
            Color.pearPrimary,     // Pear green
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
        HStack(spacing: Constants.UI.spacingSM + 4) {
            // Asset icon
            AssetIcon(ticker: asset.ticker, size: 36)
            
            // Asset info
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.ticker)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                
                Text(asset.formattedPrice)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Direction badge
            DirectionBadge(direction: direction, onTap: onToggleDirection)
            
            // Weight
            Text(weight.asWeight)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textPrimary)
                .frame(width: 50, alignment: .trailing)
            
            // Remove button
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.vertical, Constants.UI.spacingSM)
    }
}

// MARK: - Direction Badge
struct DirectionBadge: View {
    let direction: TradeDirection
    var size: BadgeSize = .regular
    var onTap: (() -> Void)? = nil
    
    enum BadgeSize {
        case small
        case regular
        
        var font: Font {
            switch self {
            case .small: return .system(size: 11, weight: .regular)
            case .regular: return .system(size: 12, weight: .medium)
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .regular: return 10
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small: return 4
            case .regular: return 6
            }
        }
    }
    
    var body: some View {
        Button(action: {
            triggerHaptic()
            onTap?()
        }) {
            HStack(spacing: Constants.UI.spacingXS) {
                Image(systemName: direction.icon)
                    .font(.system(size: size == .small ? 10 : 12, weight: .medium))
                
                Text(direction.displayName)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(Color.directionBackground(isLong: direction == .long))
            .foregroundColor(Color.directionColor(isLong: direction == .long))
            .cornerRadius(Constants.UI.spacingSM)
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
            HStack(spacing: Constants.UI.spacingSM + 4) {
                AssetIcon(ticker: asset.ticker)
                
                VStack(alignment: .leading, spacing: Constants.UI.spacingXS) {
                    Text(asset.ticker)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    HStack(spacing: Constants.UI.spacingSM) {
                        Text(asset.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                        
                        Text("Vol: \(asset.formattedVolume)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Constants.UI.spacingXS) {
                    Text(asset.formattedPrice)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text(asset.formattedChange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(asset.isPriceUp ? .pearProfit : .pearLoss)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .pearPrimary : .textSecondary)
                    .font(.system(size: 22))
            }
            .padding(.vertical, Constants.UI.spacingSM + 4)
            .padding(.horizontal, Constants.UI.cardPadding)
            .background(isSelected ? Color.pearPrimary.opacity(0.1) : Color.backgroundSecondary)
            .cornerRadius(Constants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(isSelected ? Color.pearPrimary : Color.clear, lineWidth: 1)
            )
        }
    }
    
    private func triggerHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
