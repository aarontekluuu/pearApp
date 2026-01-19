import Foundation

// MARK: - Builder Contract Service
/// Service for interacting with the Pear Protocol builder fee approval contract
@MainActor
final class BuilderContractService {
    static let shared = BuilderContractService()
    
    private init() {}
    
    // MARK: - Contract Interaction
    
    /// Encodes the approval transaction calldata for the builder fee contract
    /// - Parameters:
    ///   - builderAddress: The builder contract address to approve
    ///   - maxFeePercentage: Maximum fee percentage (as a decimal, e.g., 0.001 for 0.1%)
    /// - Returns: Hex-encoded calldata string
    func encodeApprovalCalldata(builderAddress: String, maxFeePercentage: Double) -> String {
        // ERC20-style approve function signature: approve(address,uint256)
        // Function selector: 0x095ea7b3
        let functionSelector = "0x095ea7b3"
        
        // Pad builder address to 32 bytes (64 hex chars)
        let paddedAddress = builderAddress.replacingOccurrences(of: "0x", with: "")
            .padding(toLength: 64, withPad: "0", startingAt: 0)
        
        // Convert fee percentage to uint256 (multiply by 10^18 for precision)
        let feeAmount = UInt64(maxFeePercentage * 1_000_000_000_000_000_000)
        let paddedAmount = String(format: "%064x", feeAmount)
        
        return functionSelector + paddedAddress + paddedAmount
    }
    
    /// Encodes a simpler approval calldata for Hyperliquid-specific builder approval
    /// This uses a custom contract method that may be specific to Pear Protocol
    /// - Parameters:
    ///   - userAddress: The user's wallet address
    ///   - agentAddress: The agent wallet address
    /// - Returns: Hex-encoded calldata string
    func encodeBuilderApprovalCalldata(userAddress: String, agentAddress: String) -> String {
        // Custom function signature: approveBuilder(address,address)
        // This is a placeholder - actual function signature should match the deployed contract
        let functionSelector = "0x" + sha3("approveBuilder(address,address)").prefix(8)
        
        // Pad addresses to 32 bytes each
        let paddedUser = userAddress.replacingOccurrences(of: "0x", with: "")
            .padding(toLength: 64, withPad: "0", startingAt: 0)
        let paddedAgent = agentAddress.replacingOccurrences(of: "0x", with: "")
            .padding(toLength: 64, withPad: "0", startingAt: 0)
        
        return functionSelector + paddedUser + paddedAgent
    }
    
    /// Validates a builder contract address
    /// - Parameter address: The contract address to validate
    /// - Returns: True if the address is valid
    func validateContractAddress(_ address: String) -> Bool {
        // Check if it's a valid Ethereum address format
        let pattern = "^0x[a-fA-F0-9]{40}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: address.utf16.count)
        return regex?.firstMatch(in: address, range: range) != nil
    }
    
    /// Estimates gas for the approval transaction
    /// - Returns: Estimated gas limit
    func estimateGasLimit() -> UInt64 {
        // Standard approval transaction typically uses ~50,000 gas
        // Add buffer for safety
        return 100_000
    }
    
    // MARK: - Helper Methods
    
    /// Simple SHA3 (Keccak-256) hash function selector
    /// Note: This is a simplified version. For production, use a proper crypto library
    /// - Parameter input: The function signature string
    /// - Returns: First 4 bytes (8 hex chars) of the hash
    private func sha3(_ input: String) -> String {
        // This is a placeholder implementation
        // In production, you would use a proper Keccak-256 implementation
        // For now, return a deterministic hash based on the input
        let hash = input.data(using: .utf8)?.base64EncodedString() ?? ""
        let truncated = String(hash.prefix(8))
        return truncated.replacingOccurrences(of: "[^a-fA-F0-9]", with: "", options: .regularExpression)
            .padding(toLength: 8, withPad: "0", startingAt: 0)
    }
}

// MARK: - Builder Approval Models
struct BuilderApprovalTransaction {
    let to: String
    let value: String
    let data: String
    let gasLimit: UInt64
    
    init(contractAddress: String, calldata: String, gasLimit: UInt64 = 100_000) {
        self.to = contractAddress
        self.value = "0x0" // No ETH value for approval
        self.data = calldata
        self.gasLimit = gasLimit
    }
}

// MARK: - Builder Approval Error
enum BuilderApprovalError: LocalizedError {
    case invalidContractAddress
    case invalidCalldata
    case transactionFailed(String)
    case userRejected
    
    var errorDescription: String? {
        switch self {
        case .invalidContractAddress:
            return "Invalid builder contract address"
        case .invalidCalldata:
            return "Failed to encode transaction data"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .userRejected:
            return "User rejected the transaction"
        }
    }
}
