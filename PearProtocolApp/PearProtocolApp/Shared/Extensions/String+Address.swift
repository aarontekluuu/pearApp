import Foundation

// MARK: - Ethereum Address Formatting
extension String {
    /// Truncates an Ethereum address to show first and last characters
    /// Example: "0x1234...abcd"
    var truncatedAddress: String {
        guard count > 10 else { return self }
        let prefix = String(prefix(6))
        let suffix = String(suffix(4))
        return "\(prefix)...\(suffix)"
    }
    
    /// Validates if the string is a valid Ethereum address
    var isValidEthereumAddress: Bool {
        // Check for 0x prefix and 40 hex characters
        guard hasPrefix("0x") else { return false }
        let hexPart = String(dropFirst(2))
        guard hexPart.count == 40 else { return false }
        return hexPart.allSatisfy { $0.isHexDigit }
    }
    
    /// Checksums an Ethereum address (EIP-55)
    var checksummedAddress: String? {
        guard isValidEthereumAddress else { return nil }
        // For now, return lowercase. Full checksum would require keccak256
        return lowercased()
    }
}

// MARK: - Transaction Hash Formatting
extension String {
    /// Truncates a transaction hash to show first and last characters
    /// Example: "0xabc123...def456"
    var truncatedTxHash: String {
        guard count > 16 else { return self }
        let prefix = String(prefix(10))
        let suffix = String(suffix(6))
        return "\(prefix)...\(suffix)"
    }
}
