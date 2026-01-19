import Foundation
@testable import PearProtocolApp

// MARK: - Test Fixtures
/// Provides sample data for testing
struct TestFixtures {
    
    // MARK: - Assets
    static let testAsset = Asset(
        id: "TEST",
        ticker: "TEST",
        name: "Test Asset",
        price: 100.0,
        priceChange24h: 5.0,
        priceChangePercent24h: 5.0,
        volume24h: 1_000_000,
        openInterest: 500_000,
        maxLeverage: 10.0,
        minOrderSize: 0.1,
        tickSize: 0.01
    )
    
    static let testAssets = [
        testAsset,
        Asset(
            id: "BTC",
            ticker: "BTC",
            name: "Bitcoin",
            price: 43000.0,
            priceChange24h: 1000.0,
            priceChangePercent24h: 2.38,
            volume24h: 15_000_000_000,
            openInterest: 8_000_000_000,
            maxLeverage: 50.0,
            minOrderSize: 0.001,
            tickSize: 0.1
        ),
        Asset(
            id: "ETH",
            ticker: "ETH",
            name: "Ethereum",
            price: 2300.0,
            priceChange24h: -50.0,
            priceChangePercent24h: -2.13,
            volume24h: 8_000_000_000,
            openInterest: 4_000_000_000,
            maxLeverage: 50.0,
            minOrderSize: 0.01,
            tickSize: 0.01
        )
    ]
    
    // MARK: - Baskets
    static let testBasket = Basket(
        name: "Test Basket",
        legs: [
            BasketLeg(asset: testAssets[1], direction: .long, weight: 50),
            BasketLeg(asset: testAssets[2], direction: .short, weight: 50)
        ],
        totalSize: 1000
    )
    
    static let invalidBasket = Basket(
        name: "Invalid Basket",
        legs: [
            BasketLeg(asset: testAssets[1], direction: .long, weight: 60),
            BasketLeg(asset: testAssets[2], direction: .short, weight: 30)
        ],
        totalSize: 5 // Below minimum
    )
    
    // MARK: - Positions
    static let testPosition = Position(
        id: "pos_test",
        basketId: "basket_test",
        basketName: "Test Position",
        legs: [
            PositionLeg(
                id: "leg_1",
                assetId: "BTC",
                assetTicker: "BTC",
                direction: .long,
                size: 500,
                entryPrice: 43000,
                currentPrice: 43500,
                unrealizedPnL: 25,
                unrealizedPnLPercent: 5.0,
                weight: 50
            )
        ],
        entryValue: 1000,
        currentValue: 1050,
        unrealizedPnL: 50,
        unrealizedPnLPercent: 5.0,
        realizedPnL: 0,
        marginUsed: 100,
        leverage: 10,
        takeProfitPercent: nil,
        stopLossPercent: nil,
        fundingFees: 0.5,
        status: .open,
        openedAt: Date().addingTimeInterval(-3600)
    )
    
    // MARK: - Agent Wallet
    static let testAgentWallet = AgentWallet(
        address: "0x1234567890123456789012345678901234567890",
        createdAt: Date(),
        expiresAt: Date().addingTimeInterval(Double(Constants.AgentWallet.expiryDays * 86400)),
        isApproved: true,
        approvalSignature: "0xabcdef"
    )
    
    // MARK: - API Responses
    static let testActiveAssetsResponse = ActiveAssetsResponse(
        active: [],
        topGainers: [],
        topLosers: [],
        highlighted: [],
        watchlist: []
    )
    
    static let testTradeExecuteResponse = TradeExecuteResponse(
        orderId: "order_123",
        fills: [
            Fill(
                coin: "BTC",
                px: 43000,
                sz: 500,
                side: "A",
                time: nil,
                startPosition: nil,
                dir: nil,
                closedPnl: nil,
                hash: nil,
                oid: nil,
                crossed: nil,
                closedSize: nil
            )
        ]
    )
    
    static let testPositionsResponse = PositionsResponse(
        positions: [testPosition],
        totalUnrealizedPnL: 50,
        totalMarginUsed: 100
    )
    
    // MARK: - Wallet Info
    static let testWalletAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
    static let testChainId = 42161 // Arbitrum
    
    // MARK: - Auth
    static let testAuthToken = "test_auth_token_123"
    static let testRefreshToken = "test_refresh_token_456"
    static let testClientId = "test_client_id"
    
    // MARK: - Error Scenarios
    static let networkError = NSError(domain: "TestError", code: -1009, userInfo: [
        NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
    ])
    
    static let apiError = PearAPIError.serverError
    static let walletError = WalletError.notConnected
}
