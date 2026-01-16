import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @StateObject private var repository = PearRepository.shared
    @State private var showAllAssets = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Welcome Header
                        WelcomeHeader()
                        
                        // Quick Actions
                        QuickActionsSection()
                        
                        // Featured Baskets
                        FeaturedBasketsSection()
                        
                        // Trending Assets
                        TrendingAssetsSection(
                            assets: repository.assets,
                            showAll: $showAllAssets
                        )
                        
                        // Market Overview
                        MarketOverviewSection()
                        
                        // Educational Section (for new users)
                        EducationalSection()
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await repository.fetchAssets()
        }
        .sheet(isPresented: $showAllAssets) {
            AssetSearchView { _ in }
        }
    }
}

// MARK: - Welcome Header
struct WelcomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Pear")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Trade ideas, not tokens")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.primaryGradient)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(16)
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Create Basket",
                    subtitle: "Build custom trades",
                    color: .pearPrimary
                )
                
                QuickActionCard(
                    icon: "chart.bar.fill",
                    title: "View Positions",
                    subtitle: "Manage your trades",
                    color: .blue
                )
            }
        }
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Featured Baskets Section
struct FeaturedBasketsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Featured Baskets")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {}
                    .font(.subheadline)
                    .foregroundColor(.pearPrimary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FeaturedBasketCard(
                        name: "BTC/ETH Ratio",
                        description: "Long BTC, Short ETH",
                        performance: "+12.5%",
                        isPositive: true
                    )
                    
                    FeaturedBasketCard(
                        name: "AI Tech Play",
                        description: "Long NVDA, Short INTC",
                        performance: "+8.3%",
                        isPositive: true
                    )
                    
                    FeaturedBasketCard(
                        name: "L1 Diversified",
                        description: "SOL + AVAX + NEAR",
                        performance: "-2.1%",
                        isPositive: false
                    )
                }
            }
        }
    }
}

// MARK: - Featured Basket Card
struct FeaturedBasketCard: View {
    let name: String
    let description: String
    let performance: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("30d")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(performance)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isPositive ? .pearProfit : .pearLoss)
            }
        }
        .frame(width: 160)
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Trending Assets Section
struct TrendingAssetsSection: View {
    let assets: [Asset]
    @Binding var showAll: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trending Assets")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {
                    showAll = true
                }
                .font(.subheadline)
                .foregroundColor(.pearPrimary)
            }
            
            if assets.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                    }
                }
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(assets.prefix(5)) { asset in
                        TrendingAssetRow(asset: asset)
                        
                        if asset.id != assets.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Trending Asset Row
struct TrendingAssetRow: View {
    let asset: Asset
    
    var body: some View {
        HStack(spacing: 12) {
            AssetIcon(ticker: asset.ticker, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.ticker)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(asset.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(asset.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(asset.formattedChange)
                    .font(.caption)
                    .foregroundColor(asset.isPriceUp ? .pearProfit : .pearLoss)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Market Overview Section
struct MarketOverviewSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Overview")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                MarketStatCard(
                    title: "24h Volume",
                    value: "$12.5B",
                    change: "+5.2%",
                    isPositive: true
                )
                
                MarketStatCard(
                    title: "Open Interest",
                    value: "$8.2B",
                    change: "-1.3%",
                    isPositive: false
                )
            }
        }
    }
}

// MARK: - Market Stat Card
struct MarketStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(change)
                .font(.caption)
                .foregroundColor(isPositive ? .pearProfit : .pearLoss)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

// MARK: - Educational Section
struct EducationalSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learn")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                EducationalCard(
                    icon: "questionmark.circle.fill",
                    title: "What is pair trading?",
                    subtitle: "Learn the basics of relative value trading"
                )
                
                EducationalCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Building your first basket",
                    subtitle: "Step-by-step guide to creating trades"
                )
            }
        }
    }
}

// MARK: - Educational Card
struct EducationalCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.pearPrimary)
                .frame(width: 44, height: 44)
                .background(Color.pearPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
}

#Preview {
    HomeView()
}
