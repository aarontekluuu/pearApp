import SwiftUI

// MARK: - Weight Slider
struct WeightSlider: View {
    @Binding var weight: Double
    let label: String
    var range: ClosedRange<Double> = 0...100
    var step: Double = 1
    var showPercentage: Bool = true
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if showPercentage {
                    Text(weight.asWeight)
                        .font(.headline)
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
            }
            
            HStack(spacing: 12) {
                Slider(
                    value: $weight,
                    in: range,
                    step: step
                )
                .tint(.pearPrimary)
                
                // Quick buttons
                HStack(spacing: 4) {
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
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(isSelected ? Color.pearPrimary : Color.backgroundSecondary)
                .foregroundColor(isSelected ? .white : .secondary)
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
        VStack(spacing: 12) {
            // Bar chart
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(legs) { leg in
                        Rectangle()
                            .fill(Color.directionColor(isLong: leg.isLong))
                            .frame(width: max(4, geometry.size.width * (leg.weight / 100)))
                    }
                }
            }
            .frame(height: 8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(4)
            
            // Legend
            HStack(spacing: 16) {
                ForEach(legs) { leg in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.directionColor(isLong: leg.isLong))
                            .frame(width: 8, height: 8)
                        
                        Text("\(leg.asset.ticker) \(leg.formattedWeight)")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Weights")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Equalize") {
                    equalizeWeights()
                }
                .font(.subheadline)
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
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(totalWeight.asWeight)
                    .font(.headline)
                    .foregroundColor(isValid ? .pearProfit : .pearLoss)
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
            
            if !isValid {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.pearLoss)
                    
                    Text("Weights must sum to 100%")
                        .font(.caption)
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
        .cornerRadius(12)
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
            HStack(spacing: 8) {
                Image(systemName: direction.icon)
                Text(direction.displayName)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.directionColor(isLong: direction == .long) : Color.clear)
            .foregroundColor(isSelected ? .white : .secondary)
        }
    }
    
    private func triggerHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

#Preview {
    VStack(spacing: 24) {
        WeightSlider(weight: .constant(50), label: "BTC Weight")
        
        WeightDistributionView(legs: [
            BasketLeg(asset: Asset.sampleAssets[0], direction: .long, weight: 60),
            BasketLeg(asset: Asset.sampleAssets[1], direction: .short, weight: 40)
        ])
        
        LongShortToggle(direction: .constant(.long))
    }
    .padding()
    .background(Color.backgroundPrimary)
}
