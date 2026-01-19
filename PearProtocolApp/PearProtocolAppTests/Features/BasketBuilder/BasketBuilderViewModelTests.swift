import XCTest
import Combine
@testable import PearProtocolApp

@MainActor
final class BasketBuilderViewModelTests: XCTestCase {
    
    var sut: BasketBuilderViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = BasketBuilderViewModel()
        cancellables = []
    }
    
    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Then
        XCTAssertTrue(sut.basket.legs.isEmpty)
        XCTAssertEqual(sut.positionSize, "")
        XCTAssertEqual(sut.takeProfitPercent, "")
        XCTAssertEqual(sut.stopLossPercent, "")
        XCTAssertFalse(sut.showAssetSearch)
        XCTAssertFalse(sut.showTradeReview)
        XCTAssertFalse(sut.isExecuting)
        XCTAssertNil(sut.executionError)
    }
    
    // MARK: - Computed Properties Tests
    
    func testPositionSizeValue() {
        // When
        sut.positionSize = "1000"
        
        // Then
        XCTAssertEqual(sut.positionSizeValue, 1000)
    }
    
    func testPositionSizeValueWithInvalidInput() {
        // When
        sut.positionSize = "invalid"
        
        // Then
        XCTAssertEqual(sut.positionSizeValue, 0)
    }
    
    func testIsValidPositionSize() {
        // When
        sut.positionSize = "100"
        
        // Then
        XCTAssertTrue(sut.isValidPositionSize)
    }
    
    func testIsValidPositionSizeWithInsufficientAmount() {
        // When
        sut.positionSize = "5"
        
        // Then
        XCTAssertFalse(sut.isValidPositionSize)
    }
    
    func testCanExecuteTradeWithValidBasket() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 50)
        sut.basket.addLeg(asset: TestFixtures.testAssets[2], direction: .short, weight: 50)
        sut.positionSize = "1000"
        
        // Then
        XCTAssertTrue(sut.canExecuteTrade)
    }
    
    func testCanExecuteTradeWithInvalidBasket() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 60)
        sut.positionSize = "1000"
        
        // Then
        XCTAssertFalse(sut.canExecuteTrade)
    }
    
    func testValidationErrors() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 60)
        sut.positionSize = "5"
        
        // When
        let errors = sut.validationErrors
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Weights must sum to 100%") })
        XCTAssertTrue(errors.contains { $0.contains("Minimum position size") })
    }
    
    func testMarginRequired() {
        // Given
        sut.positionSize = "1000"
        
        // When
        let margin = sut.marginRequired
        
        // Then
        XCTAssertEqual(margin, 1000 / Constants.Trading.defaultLeverage)
    }
    
    func testEstimatedFees() {
        // Given
        sut.positionSize = "1000"
        
        // When
        let fees = sut.estimatedFees
        
        // Then
        XCTAssertEqual(fees, 1000 * Constants.Trading.builderFeePercentage)
    }
    
    func testLegsDescription() {
        // Given - empty basket
        XCTAssertEqual(sut.legsDescription, "No assets selected")
        
        // When - add legs
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 50)
        sut.basket.addLeg(asset: TestFixtures.testAssets[2], direction: .short, weight: 50)
        
        // Then
        XCTAssertTrue(sut.legsDescription.contains("BTC"))
        XCTAssertTrue(sut.legsDescription.contains("LONG"))
        XCTAssertTrue(sut.legsDescription.contains("ETH"))
        XCTAssertTrue(sut.legsDescription.contains("SHORT"))
    }
    
    // MARK: - Basket Management Tests
    
    func testAddAssets() {
        // Given
        let assets = [TestFixtures.testAssets[1], TestFixtures.testAssets[2]]
        
        // When
        sut.addAssets(assets)
        
        // Then
        XCTAssertEqual(sut.basket.legs.count, 2)
        XCTAssertEqual(sut.basket.legs[0].asset.id, assets[0].id)
        XCTAssertEqual(sut.basket.legs[1].asset.id, assets[1].id)
    }
    
    func testRemoveLeg() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 50)
        sut.basket.addLeg(asset: TestFixtures.testAssets[2], direction: .short, weight: 50)
        
        // When
        sut.removeLeg(at: 0)
        
        // Then
        XCTAssertEqual(sut.basket.legs.count, 1)
        XCTAssertEqual(sut.basket.legs[0].asset.id, TestFixtures.testAssets[2].id)
    }
    
    func testToggleDirection() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 50)
        
        // When
        sut.toggleDirection(at: 0)
        
        // Then
        XCTAssertEqual(sut.basket.legs[0].direction, .short)
    }
    
    func testUpdateWeight() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 50)
        
        // When
        sut.updateWeight(at: 0, weight: 75)
        
        // Then
        XCTAssertEqual(sut.basket.legs[0].weight, 75)
    }
    
    func testEqualizeWeights() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 70)
        sut.basket.addLeg(asset: TestFixtures.testAssets[2], direction: .short, weight: 30)
        
        // When
        sut.equalizeWeights()
        
        // Then
        XCTAssertEqual(sut.basket.legs[0].weight, 50, accuracy: 0.01)
        XCTAssertEqual(sut.basket.legs[1].weight, 50, accuracy: 0.01)
    }
    
    func testSetBasketName() {
        // When
        sut.setBasketName("My Custom Basket")
        
        // Then
        XCTAssertEqual(sut.basket.name, "My Custom Basket")
    }
    
    // MARK: - Trade Preparation Tests
    
    func testPrepareTrade() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 50)
        sut.basket.addLeg(asset: TestFixtures.testAssets[2], direction: .short, weight: 50)
        sut.positionSize = "1000"
        sut.takeProfitPercent = "10"
        sut.stopLossPercent = "5"
        
        // When
        sut.prepareTrade()
        
        // Then
        XCTAssertEqual(sut.basket.totalSize, 1000)
        XCTAssertEqual(sut.basket.takeProfitPercent, 10)
        XCTAssertEqual(sut.basket.stopLossPercent, 5)
        XCTAssertTrue(sut.showTradeReview)
    }
    
    func testPrepareTradeWithEmptyTPSL() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 50)
        sut.basket.addLeg(asset: TestFixtures.testAssets[2], direction: .short, weight: 50)
        sut.positionSize = "1000"
        sut.takeProfitPercent = ""
        sut.stopLossPercent = ""
        
        // When
        sut.prepareTrade()
        
        // Then
        XCTAssertNil(sut.basket.takeProfitPercent)
        XCTAssertNil(sut.basket.stopLossPercent)
    }
    
    // MARK: - Reset Tests
    
    func testResetBasket() {
        // Given
        sut.basket.addLeg(asset: TestFixtures.testAssets[1], direction: .long, weight: 50)
        sut.basket.addLeg(asset: TestFixtures.testAssets[2], direction: .short, weight: 50)
        sut.positionSize = "1000"
        sut.takeProfitPercent = "10"
        sut.stopLossPercent = "5"
        
        // When
        sut.resetBasket()
        
        // Then
        XCTAssertTrue(sut.basket.legs.isEmpty)
        XCTAssertEqual(sut.positionSize, "")
        XCTAssertEqual(sut.takeProfitPercent, "")
        XCTAssertEqual(sut.stopLossPercent, "")
        XCTAssertNil(sut.lastExecutedTrade)
    }
    
    func testDismissError() {
        // Given
        sut.executionError = "Test error"
        sut.showError = true
        
        // When
        sut.dismissError()
        
        // Then
        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.executionError)
    }
    
    // MARK: - Preset Tests
    
    func testPresetsExist() {
        // Then
        XCTAssertFalse(BasketBuilderViewModel.presets.isEmpty)
    }
    
    func testPresetHasRequiredFields() {
        // Given
        let preset = BasketBuilderViewModel.presets.first!
        
        // Then
        XCTAssertFalse(preset.name.isEmpty)
        XCTAssertFalse(preset.description.isEmpty)
        XCTAssertFalse(preset.longAssets.isEmpty || preset.shortAssets.isEmpty)
    }
    
    func testApplyPreset() {
        // Given
        let preset = BasketBuilderViewModel.presets.first!
        let availableAssets = TestFixtures.testAssets
        
        // When
        sut.applyPreset(preset, availableAssets: availableAssets)
        
        // Then
        XCTAssertEqual(sut.basket.name, preset.name)
        XCTAssertFalse(sut.basket.legs.isEmpty)
        XCTAssertEqual(sut.basket.totalWeight, 100, accuracy: 0.01)
    }
}
