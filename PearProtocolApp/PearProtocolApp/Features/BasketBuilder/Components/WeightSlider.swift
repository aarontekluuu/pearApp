import SwiftUI

// MARK: - Weight Slider
struct WeightSlider: View {
    @Binding var weight: Double
    let label: String
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var showPercentage: Bool = true
    
    var body: some View {
        VStack(spacing: Constants.UI.spacingSM) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                if showPercentage {
                    Text(weight.asWeight)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .monospacedDigit()
                }
            }
            
            HStack(spacing: Constants.UI.spacingSM + 4) {
                Slider(
                    value: $weight,
                    in: range,
                    step: step
                )
                .tint(.pearPrimary)
                
                // Quick buttons
                HStack(spacing: Constants.UI.spacingXS) {
                    QuickWeightButton(value: 25, currentWeight: $weight)
                    QuickWeightButton(value: 50, currentWeight: $weight)
                    QuickWeightButton(value: 100, currentWeight: $weight)
                }
            }
        }
    }
}

// MARK: - Quick Weight Button
struct QuickWeightButton: View {
    let value: Double
    @Binding var currentWeight: Double
    
    var isSelected: Bool {
        abs(currentWeight - value) < 0.5
    }
    
    var body: some View {
        Button(action: {
            triggerHaptic()
            withAnimation(.easeInOut(duration: 0.2)) {
                currentWeight = value
            }
        }) {
            Text("\(Int(value))%")
                .font(.system(size: 11, weight: .regular))
                .fontWeight(.medium)
                .padding(.horizontal, Constants.UI.spacingSM)
                .padding(.vertical, Constants.UI.spacingXS + 2)
                .background(isSelected ? Color.pearPrimary : Color.backgroundTertiary)
                .foregroundColor(isSelected ? Color(hex: "080807") : .textSecondary)
                .cornerRadius(6)
        }
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Weight Distribution View
struct WeightDistributionView: View {
    let legs: [BasketLeg]
    
    var body: some View {
        VStack(spacing: Constants.UI.spacingSM + 4) {
            // Bar chart
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(legs) { leg in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.directionColor(isLong: leg.isLong))
                            .frame(width: max(4, geometry.size.width * (leg.weight / 100)))
                    }
                }
            }
            .frame(height: 10)
            .background(Color.backgroundTertiary)
            .cornerRadius(5)
            
            // Legend
            HStack(spacing: Constants.UI.spacingMD) {
                ForEach(legs) { leg in
                    HStack(spacing: Constants.UI.spacingXS + 2) {
                        Circle()
                            .fill(Color.directionColor(isLong: leg.isLong))
                            .frame(width: 8, height: 8)
                        
                        Text("\(leg.asset.ticker) \(leg.formattedWeight)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Weight Editor
struct WeightEditor: View {
    @Binding var legs: [BasketLeg]
    
    var totalWeight: Double {
        legs.reduce(0) { $0 + $1.weight }
    }
    
    var isValid: Bool {
        abs(totalWeight - 100) < 0.01
    }
    
    var body: some View {
        VStack(spacing: Constants.UI.spacingMD) {
            // Header
            HStack {
                Text("Weights")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button("Equalize") {
                    equalizeWeights()
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.pearPrimary)
            }
            
            // Sliders for each leg
            ForEach(legs.indices, id: \.self) { index in
                WeightSlider(
                    weight: $legs[index].weight,
                    label: "\(legs[index].asset.ticker) (\(legs[index].direction.displayName))"
                )
            }
            
            // Total indicator
            HStack {
                Text("Total")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text(totalWeight.asWeight)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(isValid ? .pearProfit : .pearLoss)
            }
            .padding(Constants.UI.cardPadding)
            .background(Color.backgroundSecondary)
            .cornerRadius(Constants.UI.cornerRadius)
            
            if !isValid {
                HStack(spacing: Constants.UI.spacingSM) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.pearLoss)
                        .font(.system(size: 14))
                    
                    Text("Weights must sum to 100%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.pearLoss)
                }
            }
        }
    }
    
    private func equalizeWeights() {
        guard !legs.isEmpty else { return }
        let equalWeight = 100.0 / Double(legs.count)
        for i in legs.indices {
            legs[i].weight = equalWeight
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Long/Short Toggle
struct LongShortToggle: View {
    @Binding var direction: TradeDirection
    
    var body: some View {
        HStack(spacing: 0) {
            DirectionOption(
                direction: .long,
                isSelected: direction == .long,
                onSelect: { direction = .long }
            )
            
            DirectionOption(
                direction: .short,
                isSelected: direction == .short,
                onSelect: { direction = .short }
            )
        }
        .background(Color.backgroundSecondary)
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

// MARK: - Direction Option
struct DirectionOption: View {
    let direction: TradeDirection
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: {
            triggerHaptic()
            onSelect()
        }) {
            HStack(spacing: Constants.UI.spacingSM) {
                Image(systemName: direction.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(direction.displayName)
            }
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.UI.spacingSM + 4)
            .background(isSelected ? Color.directionBackground(isLong: direction == .long) : Color.clear)
            .foregroundColor(isSelected ? Color.directionColor(isLong: direction == .long) : .textSecondary)
        }
    }
    
    private func triggerHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
