import SwiftUI

// MARK: - Asset Search View
struct AssetSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var repository = PearRepository.shared
    
    @State private var searchText = ""
    @State private var selectedAssets: Set<String> = []
    
    let onAssetsSelected: ([Asset]) -> Void
    
    var filteredAssets: [Asset] {
        repository.searchAssets(query: searchText)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    SearchBar(text: $searchText, placeholder: "Search assets...")
                        .padding()
                    
                    // Content
                    if repository.isLoadingAssets {
                        LoadingView(message: "Loading assets...")
                    } else if filteredAssets.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "No Results",
                            message: searchText.isEmpty 
                                ? "No assets available" 
                                : "No assets matching '\(searchText)'"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredAssets) { asset in
                                    SelectableAssetRow(
                                        asset: asset,
                                        isSelected: selectedAssets.contains(asset.id),
                                        onSelect: {
                                            toggleSelection(asset)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                        }
                    }
                }
                
                // Bottom action bar
                if !selectedAssets.isEmpty {
                    VStack {
                        Spacer()
                        
                        BottomActionBar(
                            selectedCount: selectedAssets.count,
                            onClear: {
                                selectedAssets.removeAll()
                            },
                            onConfirm: {
                                confirmSelection()
                            }
                        )
                    }
                }
            }
            .navigationTitle("Add Assets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.pearPrimary)
                }
            }
        }
        .task {
            await repository.fetchAssets()
        }
    }
    
    private func toggleSelection(_ asset: Asset) {
        if selectedAssets.contains(asset.id) {
            selectedAssets.remove(asset.id)
        } else {
            if selectedAssets.count < Constants.Trading.maxBasketAssets {
                selectedAssets.insert(asset.id)
            }
        }
    }
    
    private func confirmSelection() {
        let assets = repository.assets.filter { selectedAssets.contains($0.id) }
        onAssetsSelected(assets)
        dismiss()
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Bottom Action Bar
struct BottomActionBar: View {
    let selectedCount: Int
    let onClear: () -> Void
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                // Selection info
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedCount) selected")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Max \(Constants.Trading.maxBasketAssets) assets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Clear button
                Button("Clear") {
                    onClear()
                }
                .foregroundColor(.secondary)
                
                // Confirm button
                PrimaryButton(title: "Add to Basket") {
                    onConfirm()
                }
                .frame(width: 150)
            }
            .padding()
        }
        .background(Color.backgroundSecondary)
    }
}

// MARK: - Quick Asset Selection
struct QuickAssetSelector: View {
    let assets: [Asset]
    let selectedAssets: Set<String>
    let onSelect: (Asset) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular Assets")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(assets.prefix(8)) { asset in
                        QuickAssetChip(
                            asset: asset,
                            isSelected: selectedAssets.contains(asset.id),
                            onSelect: { onSelect(asset) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Quick Asset Chip
struct QuickAssetChip: View {
    let asset: Asset
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                AssetIcon(ticker: asset.ticker, size: 28)
                
                Text(asset.ticker)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.pearPrimary.opacity(0.2) : Color.backgroundSecondary)
            .foregroundColor(isSelected ? .pearPrimary : .white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.pearPrimary : Color.clear, lineWidth: 1)
            )
        }
    }
}

#Preview {
    AssetSearchView { assets in
        print("Selected: \(assets.map { $0.ticker })")
    }
}
