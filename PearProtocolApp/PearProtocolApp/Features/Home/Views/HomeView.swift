import SwiftUI

// MARK: - Home View
struct HomeView: View {
    @StateObject private var repository = PearRepository.shared
    @State private var showAllAssets = false
    @Environment(\.tabSelection) var tabSelection
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                // Top gradient header
                TopGradientHeader()
                
                ScrollView {
                    VStack(spacing: Constants.UI.spacingLG) {
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
                        
                        // Market Overview - REMOVED (no data available)
                        // MarketOverviewSection(repository: repository)
                        
                        // Educational Section (for new users)
                        EducationalSection()
                        
                        Spacer(minLength: 40)
                    }
                    .padding(Constants.UI.safeAreaMargin)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            // Fetch assets and market data in parallel
            async let assetsTask = repository.fetchAssets()
            async let marketDataTask = repository.fetchMarketData()
            
            await assetsTask
            await marketDataTask
        }
        .sheet(isPresented: $showAllAssets) {
            AssetSearchView { assets in
                // Add assets to shared basket and navigate to trade tab
                let viewModel = BasketBuilderViewModel.shared
                viewModel.addAssets(assets)
                
                // Navigate to trade tab using environment
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    tabSelection.wrappedValue = .build
                }
            }
        }
    }
}

// MARK: - Welcome Header
struct WelcomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: Constants.UI.spacingXS) {
                    Text("Welcome to Pear")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text("The Home of Long/Short Trading")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Pear Icon with glow effect
                ZStack {
                    Circle()
                        .fill(Color.pearPrimary.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image("pear")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
            }
        }
        .padding(Constants.UI.cardPadding)
        .background(Color.backgroundSecondary)
        .cornerRadius(Constants.UI.cornerRadiusLarge)
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    @Environment(\.tabSelection) var tabSelection
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSM + 4) {
            Text("Quick Actions")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            HStack(spacing: Constants.UI.spacingSM + 4) {
                QuickActionCard(
                    icon: "plus.circle.fill",
                    title: "Create Basket",
                    subtitle: "Build custom trades",
                    color: .pearPrimary,
                    action: {
                        tabSelection.wrappedValue = .build
                    }
                )
                
                QuickActionCard(
                    icon: "chart.bar.fill",
                    title: "View Positions",
                    subtitle: "Manage your trades",
                    color: Color(hex: "3B82F6"),
                    action: {
                        tabSelection.wrappedValue = .portfolio
                    }
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
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.tap()
            action()
        }) {
            VStack(alignment: .leading, spacing: Constants.UI.spacingSM + 4) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: Constants.UI.spacingXS) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Constants.UI.cardPadding)
            .background(Color.backgroundSecondary)
            .cornerRadius(Constants.UI.cornerRadius)
        }
    }
}

// MARK: - Featured Baskets Section
struct FeaturedBasketsSection: View {
    @Environment(\.tabSelection) var tabSelection
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSM + 4) {
            HStack {
                Text("Featured Baskets")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button("See All") {
                    HapticManager.shared.lightTap()
                    tabSelection.wrappedValue = .build
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.pearPrimary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.UI.spacingSM + 4) {
                    FeaturedBasketCard(
                        name: "BTC/ETH Ratio",
                        description: "Long BTC, Short ETH",
                        performance: nil // No fake data
                    )
                    
                    FeaturedBasketCard(
                        name: "AI Tech Play",
                        description: "Long AI tokens, Short traditional",
                        performance: nil
                    )
                    
                    FeaturedBasketCard(
                        name: "L1 Diversified",
                        description: "SOL + AVAX + NEAR",
                        performance: nil
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
    let performance: String? // Optional - only show if we have real data
    
    var body: some View {
        Button(action: {
            HapticManager.shared.cardTap()
        }) {
            VStack(alignment: .leading, spacing: Constants.UI.spacingSM + 4) {
                VStack(alignment: .leading, spacing: Constants.UI.spacingXS) {
                    Text(name)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                
                if let performance = performance {
                    HStack(spacing: Constants.UI.spacingSM) {
                        Text("30d")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textQuaternary)
                        
                        Text(performance)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(performance.hasPrefix("+") ? .pearProfit : .pearLoss)
                    }
                } else {
                    Text("Tap to create")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.pearPrimary.opacity(0.7))
                }
            }
            .frame(width: 160)
            .padding(Constants.UI.cardPadding)
            .background(Color.backgroundSecondary)
            .cornerRadius(Constants.UI.cornerRadius)
        }
    }
}

// MARK: - Trending Assets Section
struct TrendingAssetsSection: View {
    let assets: [Asset]
    @Binding var showAll: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSM + 4) {
            HStack {
                Text("Trending Assets")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Button("See All") {
                    showAll = true
                }
                .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.pearPrimary)
            }
            
            if assets.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                    }
                }
                .padding(Constants.UI.cardPadding)
                .background(Color.backgroundSecondary)
                .cornerRadius(Constants.UI.cornerRadius)
            } else {
                VStack(spacing: 0) {
                    ForEach(assets.prefix(5)) { asset in
                        TrendingAssetRow(asset: asset)
                        
                        if asset.id != assets.prefix(5).last?.id {
                            Divider()
                                .background(Color.divider)
                                .padding(.leading, 56)
                        }
                    }
                }
                .padding(Constants.UI.cardPadding)
                .background(Color.backgroundSecondary)
                .cornerRadius(Constants.UI.cornerRadius)
            }
        }
    }
}

// MARK: - Trending Asset Row
struct TrendingAssetRow: View {
    let asset: Asset
    
    var body: some View {
        HStack(spacing: Constants.UI.spacingSM + 4) {
            AssetIcon(ticker: asset.ticker, size: 40)
            
            VStack(alignment: .leading, spacing: Constants.UI.spacingXS) {
                Text(asset.ticker)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(asset.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Constants.UI.spacingXS) {
                Text(asset.formattedPrice)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                
                Text(asset.formattedChange)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(asset.isPriceUp ? .pearProfit : .pearLoss)
            }
        }
        .padding(.vertical, Constants.UI.spacingSM)
    }
}

// MARK: - Market Overview Section
struct MarketOverviewSection: View {
    @ObservedObject var repository: PearRepository
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSM + 4) {
            Text("Market Overview")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            if repository.isLoadingMarketData {
                HStack(spacing: Constants.UI.spacingSM + 4) {
                    MarketStatCardSkeleton()
                    MarketStatCardSkeleton()
                }
            } else if let marketData = repository.marketData {
                HStack(spacing: Constants.UI.spacingSM + 4) {
                    MarketStatCard(
                        title: "24h Volume",
                        value: "$\(marketData.dailyMetrics.formattedTotalVolume)",
                        change: "Avg funding: \(marketData.dailyMetrics.formattedAverageFundingRate)",
                        isPositive: true,
                        showFundingRate: false
                    )
                    
                    MarketStatCard(
                        title: "Open Interest",
                        value: "$\(marketData.dailyMetrics.totalOpenInterest.asCompactNumber)",
                        change: "\(marketData.dailyMetrics.activeMarkets) active markets",
                        isPositive: true,
                        showFundingRate: false
                    )
                }
            } else {
                // Fallback to placeholder if market data not available
                HStack(spacing: Constants.UI.spacingSM + 4) {
                    MarketStatCard(
                        title: "24h Volume",
                        value: "—",
                        change: "—",
                        isPositive: true,
                        showFundingRate: false
                    )
                    
                    MarketStatCard(
                        title: "Open Interest",
                        value: "—",
                        change: "—",
                        isPositive: true,
                        showFundingRate: false
                    )
                }
            }
        }
    }
}

// MARK: - Market Stat Card Skeleton
struct MarketStatCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSM) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 12)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 20)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.UI.cardPadding)
        .background(Color.backgroundSecondary)
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

// MARK: - Market Stat Card
struct MarketStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    var showFundingRate: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSM) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textTertiary)
            
            Text(value)
                .font(.system(size: 23, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            if showFundingRate {
                HStack(spacing: Constants.UI.spacingXS) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(change)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isPositive ? .pearProfit : .pearLoss)
            } else {
                Text(change)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.UI.cardPadding)
        .background(Color.backgroundSecondary)
        .cornerRadius(Constants.UI.cornerRadius)
    }
}

// MARK: - Educational Section
struct EducationalSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.UI.spacingSM + 4) {
            Text("Learn")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.textPrimary)
            
            VStack(spacing: Constants.UI.spacingSM + 4) {
                EducationalCard(
                    icon: "questionmark.circle.fill",
                    title: "What is pair trading?",
                    subtitle: "Learn the basics of relative value trading",
                    url: "https://pearprotocol.io/learn/pair-trading"
                )
                
                EducationalCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Building your first basket",
                    subtitle: "Step-by-step guide to creating trades",
                    url: "https://pearprotocol.io/learn/building-baskets"
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
    let url: String?
    
    init(icon: String, title: String, subtitle: String, url: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.url = url
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            if let urlString = url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: Constants.UI.cardPadding) {
                ZStack {
                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                        .fill(Color.pearPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.pearPrimary)
                }
                
                VStack(alignment: .leading, spacing: Constants.UI.spacingXS) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.iconTertiary)
            }
            .padding(Constants.UI.cardPadding)
            .background(Color.backgroundSecondary)
            .cornerRadius(Constants.UI.cornerRadius)
        }
    }
}
