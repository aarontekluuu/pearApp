import XCTest
@testable import PearProtocolApp

final class BasketTests: XCTestCase {
    
    var testAssets: [Asset]!
    
    override func setUp() {
        super.setUp()
        testAssets = TestFixtures.testAssets
    }
    
    // MARK: - Initialization Tests
    
    func testBasketInitialization() {
        // Given
        let basket = Basket()
        
        // Then
        XCTAssertNotNil(basket.id)
        XCTAssertTrue(basket.legs.isEmpty)
        XCTAssertEqual(basket.totalSize, 0)
        XCTAssertNil(basket.takeProfitPercent)
        XCTAssertNil(basket.stopLossPercent)
    }
    
    func testBasketWithLegsInitialization() {
        // Given
        let legs = [
            BasketLeg(asset: testAssets[0], direction: .long, weight: 50),
            BasketLeg(asset: testAssets[1], direction: .short, weight: 50)
        ]
        
        // When
        let basket = Basket(name: "Test Basket", legs: legs, totalSize: 1000)
        
        // Then
        XCTAssertEqual(basket.name, "Test Basket")
        XCTAssertEqual(basket.legs.count, 2)
        XCTAssertEqual(basket.totalSize, 1000)
    }
    
    // MARK: - Computed Properties Tests
    
    func testTotalWeight() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 40)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 60)
        
        // Then
        XCTAssertEqual(basket.totalWeight, 100)
    }
    
    func testIsValidWithCorrectWeights() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 50)
        basket.totalSize = 100
        
        // Then
        XCTAssertTrue(basket.isValid)
    }
    
    func testIsValidWithIncorrectWeights() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 40)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 50)
        basket.totalSize = 100
        
        // Then
        XCTAssertFalse(basket.isValid, "Basket with weights not summing to 100 should be invalid")
    }
    
    func testIsValidWithInsufficientSize() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 50)
        basket.totalSize = 5 // Below minimum
        
        // Then
        XCTAssertFalse(basket.isValid, "Basket below minimum size should be invalid")
    }
    
    func testIsValidWithNoLegs() {
        // Given
        var basket = Basket()
        basket.totalSize = 100
        
        // Then
        XCTAssertFalse(basket.isValid, "Basket with no legs should be invalid")
    }
    
    func testDisplayNameWithCustomName() {
        // Given
        var basket = Basket(name: "Custom Name")
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 50)
        
        // Then
        XCTAssertEqual(basket.displayName, "Custom Name")
    }
    
    func testDisplayNameWithPairTrade() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[1], direction: .long, weight: 50)  // BTC
        basket.addLeg(asset: testAssets[2], direction: .short, weight: 50) // ETH
        
        // Then
        XCTAssertEqual(basket.displayName, "BTC/ETH")
    }
    
    func testDisplayNameWithMultipleAssets() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 33.33)
        basket.addLeg(asset: testAssets[1], direction: .long, weight: 33.33)
        basket.addLeg(asset: testAssets[2], direction: .short, weight: 33.34)
        
        // Then
        XCTAssertEqual(basket.displayName, "Custom Basket")
    }
    
    func testMarginRequired() {
        // Given
        var basket = Basket()
        basket.totalSize = 1000
        
        // When
        let margin = basket.marginRequired
        
        // Then
        XCTAssertEqual(margin, 1000 / Constants.Trading.defaultLeverage)
    }
    
    func testEstimatedFees() {
        // Given
        var basket = Basket()
        basket.totalSize = 1000
        
        // When
        let fees = basket.estimatedFees
        
        // Then
        XCTAssertEqual(fees, 1000 * Constants.Trading.builderFeePercentage)
    }
    
    // MARK: - Validation Errors Tests
    
    func testValidationErrorsEmpty() {
        // Given
        let basket = Basket()
        
        // When
        let errors = basket.validationErrors
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Add at least one asset") })
    }
    
    func testValidationErrorsIncorrectWeights() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 40)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 50)
        basket.totalSize = 100
        
        // When
        let errors = basket.validationErrors
        
        // Then
        XCTAssertTrue(errors.contains { $0.contains("Weights must sum to 100%") })
    }
    
    func testValidationErrorsInsufficientSize() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 50)
        basket.totalSize = 5
        
        // When
        let errors = basket.validationErrors
        
        // Then
        XCTAssertTrue(errors.contains { $0.contains("Minimum position size") })
    }
    
    func testValidationErrorsTooManyAssets() {
        // Given
        var basket = Basket()
        for i in 0..<15 {
            let asset = Asset(
                id: "ASSET\(i)",
                ticker: "ASSET\(i)",
                name: "Asset \(i)",
                price: 100,
                priceChange24h: 0,
                priceChangePercent24h: 0,
                volume24h: 0,
                maxLeverage: 1,
                minOrderSize: 0.1,
                tickSize: 0.01
            )
            basket.addLeg(asset: asset, direction: .long, weight: 100.0 / 15.0)
        }
        basket.totalSize = 100
        
        // When
        let errors = basket.validationErrors
        
        // Then
        XCTAssertTrue(errors.contains { $0.contains("Maximum") && $0.contains("assets per basket") })
    }
    
    // MARK: - Mutating Methods Tests
    
    func testAddLeg() {
        // Given
        var basket = Basket()
        
        // When
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 0)
        
        // Then
        XCTAssertEqual(basket.legs.count, 1)
        XCTAssertEqual(basket.legs[0].asset.id, testAssets[0].id)
        XCTAssertEqual(basket.legs[0].direction, .long)
    }
    
    func testAddLegAutoBalancesWeights() {
        // Given
        var basket = Basket()
        
        // When
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 0)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 0)
        
        // Then
        XCTAssertEqual(basket.legs[0].weight, 50, accuracy: 0.01)
        XCTAssertEqual(basket.legs[1].weight, 50, accuracy: 0.01)
    }
    
    func testAddLegDoesNotAddDuplicate() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        
        // When
        basket.addLeg(asset: testAssets[0], direction: .short, weight: 50)
        
        // Then
        XCTAssertEqual(basket.legs.count, 1, "Should not add duplicate asset")
    }
    
    func testRemoveLegAtIndex() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 50)
        
        // When
        basket.removeLeg(at: 0)
        
        // Then
        XCTAssertEqual(basket.legs.count, 1)
        XCTAssertEqual(basket.legs[0].asset.id, testAssets[1].id)
    }
    
    func testRemoveLegByAssetId() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 50)
        
        // When
        basket.removeLeg(assetId: testAssets[0].id)
        
        // Then
        XCTAssertEqual(basket.legs.count, 1)
        XCTAssertEqual(basket.legs[0].asset.id, testAssets[1].id)
    }
    
    func testUpdateLegWeight() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        
        // When
        basket.updateLegWeight(at: 0, weight: 75)
        
        // Then
        XCTAssertEqual(basket.legs[0].weight, 75)
    }
    
    func testUpdateLegWeightClampsToRange() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        
        // When
        basket.updateLegWeight(at: 0, weight: 150)
        
        // Then
        XCTAssertEqual(basket.legs[0].weight, 100, "Weight should be clamped to 100")
    }
    
    func testToggleLegDirection() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 50)
        
        // When
        basket.toggleLegDirection(at: 0)
        
        // Then
        XCTAssertEqual(basket.legs[0].direction, .short)
        
        // When - toggle again
        basket.toggleLegDirection(at: 0)
        
        // Then
        XCTAssertEqual(basket.legs[0].direction, .long)
    }
    
    func testEqualizeWeights() {
        // Given
        var basket = Basket()
        basket.addLeg(asset: testAssets[0], direction: .long, weight: 70)
        basket.addLeg(asset: testAssets[1], direction: .short, weight: 20)
        basket.addLeg(asset: testAssets[2], direction: .long, weight: 10)
        
        // When
        basket.equalizeWeights()
        
        // Then
        let expectedWeight = 100.0 / 3.0
        for leg in basket.legs {
            XCTAssertEqual(leg.weight, expectedWeight, accuracy: 0.01)
        }
    }
}
