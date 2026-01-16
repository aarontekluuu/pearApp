import SwiftUI

// MARK: - Basket Builder View
struct BasketBuilderView: View {
    @StateObject private var viewModel = BasketBuilderViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
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
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                
                // Bottom Execute Button
                VStack {
                    Spacer()
                    
                    BottomExecuteBar(viewModel: viewModel)
                }
            }
            .navigationTitle("Build Basket")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        viewModel.resetBasket()
                    }
                    .foregroundColor(.secondary)
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
}

// MARK: - Basket Name Section
struct BasketNameSection: View {
    @Binding var name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Basket Name (Optional)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
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
        Button(action: onAdd) {
            VStack(spacing: 16) {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 40))
                    .foregroundColor(.pearPrimary)
                
                Text("Add assets to your basket")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.pearPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
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
                    .foregroundColor(.white)
                
                Text(leg.asset.formattedPrice)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            DirectionBadge(direction: leg.direction, onTap: onToggleDirection)
            
            Text(leg.formattedWeight)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 50, alignment: .trailing)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Equalize") {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Position Size")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Text("$")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                TextField("0.00", text: $viewModel.positionSize)
                    .font(.title2)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
            
            // Quick amount buttons
            HStack(spacing: 8) {
                ForEach([100, 500, 1000, 5000], id: \.self) { amount in
                    Button(action: {
                        viewModel.positionSize = "\(amount)"
                    }) {
                        Text("$\(amount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.backgroundSecondary)
                            .foregroundColor(.white)
                            .cornerRadius(8)
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
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Take Profit / Stop Loss")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Optional")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Take Profit %")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., 10", text: $viewModel.takeProfitPercent)
                            .textFieldStyle(PearTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stop Loss %")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
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
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                SummaryRowItem(label: "Position Size", value: viewModel.positionSizeValue.asCurrency)
                SummaryRowItem(label: "Margin Required", value: viewModel.marginRequired.asCurrency)
                SummaryRowItem(label: "Estimated Fees", value: viewModel.estimatedFees.asCurrency)
                
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
    var valueColor: Color = .white
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
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
            
            PrimaryButton(
                title: "Review Trade",
                isDisabled: !viewModel.canExecuteTrade
            ) {
                viewModel.prepareTrade()
            }
            .padding()
        }
        .background(Color.backgroundSecondary)
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

#Preview {
    BasketBuilderView()
}
