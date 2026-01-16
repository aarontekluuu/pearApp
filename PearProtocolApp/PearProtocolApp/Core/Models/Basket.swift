import Foundation

// MARK: - Basket Model
/// Represents a basket/pair trade configuration
struct Basket: Identifiable, Codable {
    let id: UUID
    var name: String
    var legs: [BasketLeg]
    var totalSize: Double // USDC amount
    var takeProfitPercent: Double?
    var stopLossPercent: Double?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String = "",
        legs: [BasketLeg] = [],
        totalSize: Double = 0,
        takeProfitPercent: Double? = nil,
        stopLossPercent: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.legs = legs
        self.totalSize = totalSize
        self.takeProfitPercent = takeProfitPercent
        self.stopLossPercent = stopLossPercent
        self.createdAt = createdAt
    }
    
    // MARK: - Computed Properties
    var totalWeight: Double {
        legs.reduce(0) { $0 + $1.weight }
    }
    
    var isValid: Bool {
        !legs.isEmpty &&
        abs(totalWeight - 100) < 0.01 &&
        totalSize >= Constants.Trading.minPositionSize
    }
    
    var displayName: String {
        if !name.isEmpty {
            return name
        }
        // Auto-generate name from legs
        let longLegs = legs.filter { $0.direction == .long }.map { $0.asset.ticker }
        let shortLegs = legs.filter { $0.direction == .short }.map { $0.asset.ticker }
        
        if longLegs.count == 1 && shortLegs.count == 1 {
            return "\(longLegs[0])/\(shortLegs[0])"
        }
        return "Custom Basket"
    }
    
    var marginRequired: Double {
        // Simplified margin calculation
        // In production, this would be calculated per-leg based on Hyperliquid requirements
        totalSize / Constants.Trading.defaultLeverage
    }
    
    var estimatedFees: Double {
        totalSize * Constants.Trading.builderFeePercentage
    }
    
    // MARK: - Validation
    var validationErrors: [String] {
        var errors: [String] = []
        
        if legs.isEmpty {
            errors.append("Add at least one asset to your basket")
        }
        
        if abs(totalWeight - 100) >= 0.01 {
            errors.append("Weights must sum to 100%")
        }
        
        if totalSize < Constants.Trading.minPositionSize {
            errors.append("Minimum position size is $\(Int(Constants.Trading.minPositionSize))")
        }
        
        if legs.count > Constants.Trading.maxBasketAssets {
            errors.append("Maximum \(Constants.Trading.maxBasketAssets) assets per basket")
        }
        
        return errors
    }
    
    // MARK: - Mutating Methods
    mutating func addLeg(asset: Asset, direction: TradeDirection = .long, weight: Double = 0) {
        // Check if asset already exists
        if legs.contains(where: { $0.asset.id == asset.id }) {
            return
        }
        
        let leg = BasketLeg(
            asset: asset,
            direction: direction,
            weight: weight
        )
        legs.append(leg)
        
        // Auto-balance weights if weight is 0
        if weight == 0 {
            equalizeWeights()
        }
    }
    
    mutating func removeLeg(at index: Int) {
        guard legs.indices.contains(index) else { return }
        legs.remove(at: index)
        equalizeWeights()
    }
    
    mutating func removeLeg(assetId: String) {
        legs.removeAll { $0.asset.id == assetId }
        equalizeWeights()
    }
    
    mutating func updateLegWeight(at index: Int, weight: Double) {
        guard legs.indices.contains(index) else { return }
        legs[index].weight = max(0, min(100, weight))
    }
    
    mutating func toggleLegDirection(at index: Int) {
        guard legs.indices.contains(index) else { return }
        legs[index].direction = legs[index].direction == .long ? .short : .long
    }
    
    mutating func equalizeWeights() {
        guard !legs.isEmpty else { return }
        let equalWeight = 100.0 / Double(legs.count)
        for i in legs.indices {
            legs[i].weight = equalWeight
        }
    }
}

// MARK: - Basket Leg
/// Represents a single leg/component of a basket trade
struct BasketLeg: Identifiable, Codable, Hashable {
    let id: UUID
    let asset: Asset
    var direction: TradeDirection
    var weight: Double // Percentage (0-100)
    
    init(
        id: UUID = UUID(),
        asset: Asset,
        direction: TradeDirection = .long,
        weight: Double = 0
    ) {
        self.id = id
        self.asset = asset
        self.direction = direction
        self.weight = weight
    }
    
    // MARK: - Computed Properties
    var isLong: Bool {
        direction == .long
    }
    
    var formattedWeight: String {
        weight.asWeight
    }
    
    func notionalSize(totalBasketSize: Double) -> Double {
        totalBasketSize * (weight / 100)
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BasketLeg, rhs: BasketLeg) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Trade Direction
enum TradeDirection: String, Codable, CaseIterable {
    case long = "LONG"
    case short = "SHORT"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .long: return "arrow.up.right"
        case .short: return "arrow.down.right"
        }
    }
    
    var opposite: TradeDirection {
        self == .long ? .short : .long
    }
}

// MARK: - Sample Data
extension Basket {
    static let sample = Basket(
        name: "BTC/ETH Pair",
        legs: [
            BasketLeg(asset: Asset.sampleAssets[0], direction: .long, weight: 50),
            BasketLeg(asset: Asset.sampleAssets[1], direction: .short, weight: 50)
        ],
        totalSize: 1000,
        takeProfitPercent: 10,
        stopLossPercent: 5
    )
    
    static let empty = Basket()
}
