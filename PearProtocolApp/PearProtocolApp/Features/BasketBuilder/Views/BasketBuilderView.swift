import SwiftUI

// MARK: - Basket Builder View
struct BasketBuilderView: View {
    @ObservedObject private var viewModel = BasketBuilderViewModel.shared
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissKeyboard()
                    }
                
                // Top gradient header
                TopGradientHeader()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Basket Name
                        BasketNameSection(name: $viewModel.basket.name)
                        
                        // Assets Section
                        AssetsSection(viewModel: viewModel)
                        
                        // Weight Distribution
                        if !viewModel.basket.legs.isEmpty {
                            WeightSection(viewModel: viewModel)
                        }
                        
                        // Position Size
                        PositionSizeSection(viewModel: viewModel)
                        
                        // TP/SL Section
                        TakeProfitStopLossSection(viewModel: viewModel)
                        
                        // Validation Errors
                        if !viewModel.validationErrors.isEmpty {
                            ValidationErrorsView(errors: viewModel.validationErrors)
                        }
                        
                        // Trade Summary
                        if viewModel.canExecuteTrade {
                            TradeSummaryCard(viewModel: viewModel)
                        }
                        
                        // Add bottom padding to account for fixed CTA bar
                        Spacer(minLength: 100)
                            .frame(height: 100)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Bottom Execute Button - Fixed at bottom
                VStack {
                    Spacer()
                    BottomExecuteBar(viewModel: viewModel)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        viewModel.resetBasket()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            dismissKeyboard()
                        }
                        .foregroundColor(.pearPrimary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAssetSearch) {
                AssetSearchView { assets in
                    viewModel.addAssets(assets)
                }
            }
            .sheet(isPresented: $viewModel.showTradeReview) {
                TradeReviewView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.executionError ?? "An unexpected error occurred")
            }
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Basket Name Section
struct BasketNameSection: View {
    @Binding var name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Basket Name (Optional)")
                .font(.subheadline)
                .foregroundColor(.textTertiary)
            
            TextField("e.g., BTC/ETH Ratio Play", text: $name)
                .textFieldStyle(PearTextFieldStyle())
        }
    }
}

// MARK: - Assets Section
struct AssetsSection: View {
    @ObservedObject var viewModel: BasketBuilderViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Assets")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.tap()
                    viewModel.showAssetSearch = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.subheadline)
                    .foregroundColor(.pearPrimary)
                }
            }
            
            if viewModel.basket.legs.isEmpty {
                EmptyAssetsCard {
                    viewModel.showAssetSearch = true
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.basket.legs.indices, id: \.self) { index in
                        let leg = viewModel.basket.legs[index]
                        BasketLegCard(
                            leg: leg,
                            onToggleDirection: {
                                viewModel.toggleDirection(at: index)
                            },
                            onRemove: {
                                viewModel.removeLeg(at: index)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Empty Assets Card
struct EmptyAssetsCard: View {
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.tap()
            onAdd()
        }) {
            VStack(spacing: 16) {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 40))
                    .foregroundColor(.pearPrimary.opacity(0.8))
                
                Text("Add assets to your basket")
                    .font(.subheadline)
                    .foregroundColor(.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.pearPrimary.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
    }
}

// MARK: - Basket Leg Card
struct BasketLegCard: View {
    let leg: BasketLeg
    let onToggleDirection: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AssetIcon(ticker: leg.asset.ticker, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(leg.asset.ticker)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Text(leg.asset.formattedPrice)
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            
            Spacer()
            
            DirectionBadge(direction: leg.direction, onTap: {
                HapticManager.shared.toggle()
                onToggleDirection()
            })
            
            Text(leg.formattedWeight)
                .font(.headline)
                .foregroundColor(.textPrimary)
                .frame(width: 50, alignment: .trailing)
            
            Button(action: {
                HapticManager.shared.delete()
                onRemove()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.iconTertiary)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Weight Section
struct WeightSection: View {
    @ObservedObject var viewModel: BasketBuilderViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight Distribution")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button("Equalize") {
                    HapticManager.shared.tap()
                    viewModel.equalizeWeights()
                }
                .font(.subheadline)
                .foregroundColor(.pearPrimary)
            }
            
            WeightDistributionView(legs: viewModel.basket.legs)
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
            
            // Weight sliders
            VStack(spacing: 16) {
                ForEach(viewModel.basket.legs.indices, id: \.self) { index in
                    WeightSlider(
                        weight: Binding(
                            get: { viewModel.basket.legs[index].weight },
                            set: { viewModel.updateWeight(at: index, weight: $0) }
                        ),
                        label: viewModel.basket.legs[index].asset.ticker
                    )
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Position Size Section
struct PositionSizeSection: View {
    @ObservedObject var viewModel: BasketBuilderViewModel
    @StateObject private var walletService = WalletService.shared
    @State private var usePercentage = false
    @State private var percentageValue: Double = 25
    @FocusState private var isTextFieldFocused: Bool
    
    private var availableUSDC: Double {
        walletService.walletInfo?.usdcBalance ?? 0
    }
    
    private var calculatedAmount: Double {
        if usePercentage {
            return availableUSDC * (percentageValue / 100)
        }
        return Double(viewModel.positionSize) ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Position Size")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                // Toggle between $ and %
                HStack(spacing: 4) {
                    Text("$")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(!usePercentage ? .pearPrimary : .textTertiary)
                    
                    Toggle("", isOn: $usePercentage)
                        .toggleStyle(SwitchToggleStyle(tint: .pearPrimary))
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onChange(of: usePercentage) { _, newValue in
                            HapticManager.shared.toggle()
                            if newValue {
                                // Calculate percentage from current amount
                                if let amount = Double(viewModel.positionSize), availableUSDC > 0 {
                                    percentageValue = min(100, (amount / availableUSDC) * 100)
                                }
                            } else {
                                // Set amount from percentage
                                viewModel.positionSize = String(format: "%.2f", calculatedAmount)
                            }
                        }
                    
                    Text("%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(usePercentage ? .pearPrimary : .textTertiary)
                }
            }
            
            if usePercentage {
                // Percentage slider
                VStack(spacing: 16) {
                    HStack {
                        Text("\(Int(percentageValue))%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text(calculatedAmount.asCurrency)
                            .font(.title3)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Slider(value: $percentageValue, in: 1...100, step: 1)
                        .tint(.pearPrimary)
                        .onChange(of: percentageValue) { _, newValue in
                            viewModel.positionSize = String(format: "%.2f", availableUSDC * (newValue / 100))
                        }
                    
                    // Quick percentage buttons
                    HStack(spacing: 8) {
                        ForEach([25, 50, 75, 100], id: \.self) { percent in
                            Button(action: {
                                HapticManager.shared.selection()
                                percentageValue = Double(percent)
                                viewModel.positionSize = String(format: "%.2f", availableUSDC * (Double(percent) / 100))
                            }) {
                                Text("\(percent)%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Int(percentageValue) == percent ? Color.pearPrimary.opacity(0.2) : Color.backgroundSecondary)
                                    .foregroundColor(Int(percentageValue) == percent ? .pearPrimary : .textSecondary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Available balance info
                    HStack {
                        Text("Available:")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                        Text(availableUSDC.asCurrency)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
            } else {
                // Dollar amount input
                HStack(spacing: 12) {
                    Text("$")
                        .font(.title2)
                        .foregroundColor(.textTertiary)
                    
                    TextField("0.00", text: $viewModel.positionSize)
                        .font(.title2)
                        .keyboardType(.decimalPad)
                        .foregroundColor(.textPrimary)
                        .focused($isTextFieldFocused)
                }
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
                .onTapGesture {
                    isTextFieldFocused = true
                }
                
                // Quick amount buttons
                HStack(spacing: 8) {
                    ForEach([100, 500, 1000, 5000], id: \.self) { amount in
                        Button(action: {
                            HapticManager.shared.selection()
                            viewModel.positionSize = "\(amount)"
                            isTextFieldFocused = false
                        }) {
                            Text("$\(amount)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.backgroundSecondary)
                                .foregroundColor(.textSecondary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - TP/SL Section
struct TakeProfitStopLossSection: View {
    @ObservedObject var viewModel: BasketBuilderViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                HapticManager.shared.toggle()
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Take Profit / Stop Loss")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    Text("Optional")
                        .font(.caption)
                        .foregroundColor(.textQuaternary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.iconTertiary)
                }
            }
            
            if isExpanded {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Take Profit %")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                        
                        TextField("e.g., 10", text: $viewModel.takeProfitPercent)
                            .textFieldStyle(PearTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stop Loss %")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                        
                        TextField("e.g., 5", text: $viewModel.stopLossPercent)
                            .textFieldStyle(PearTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                }
            }
        }
    }
}

// MARK: - Validation Errors View
struct ValidationErrorsView: View {
    let errors: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(errors, id: \.self) { error in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.pearLoss)
                        .font(.caption)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.pearLoss)
                }
            }
        }
        .padding()
        .background(Color.pearLoss.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Trade Summary Card
struct TradeSummaryCard: View {
    @ObservedObject var viewModel: BasketBuilderViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trade Summary")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 12) {
                SummaryRowItem(label: "Position Size", value: viewModel.positionSizeValue.asCurrency)
                SummaryRowItem(label: "Margin Required", value: viewModel.marginRequired.asCurrency)
                SummaryRowItem(label: "Estimated Fees", value: viewModel.estimatedFees.asCurrency, labelOpacity: 0.5)
                
                if let tp = Double(viewModel.takeProfitPercent), tp > 0 {
                    SummaryRowItem(label: "Take Profit", value: "+\(tp)%", valueColor: .pearProfit)
                }
                
                if let sl = Double(viewModel.stopLossPercent), sl > 0 {
                    SummaryRowItem(label: "Stop Loss", value: "-\(sl)%", valueColor: .pearLoss)
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }
}

// MARK: - Summary Row Item
struct SummaryRowItem: View {
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

// MARK: - Bottom Execute Bar
struct BottomExecuteBar: View {
    @ObservedObject var viewModel: BasketBuilderViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.divider)
            
            PrimaryButton(
                title: "Review Trade",
                isDisabled: !viewModel.canExecuteTrade
            ) {
                viewModel.prepareTrade()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(
            Color.backgroundSecondary
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Pear Text Field Style
struct PearTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.backgroundSecondary)
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}
