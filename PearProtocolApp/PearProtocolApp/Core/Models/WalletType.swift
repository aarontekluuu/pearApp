import Foundation
import UIKit

// MARK: - Wallet Type
enum WalletType: String, CaseIterable, Identifiable {
    case metamask
    case rainbow
    case coinbase
    case trust
    case zerion
    case safe
    case uniswap
    case rabby
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .metamask:
            return "MetaMask"
        case .rainbow:
            return "Rainbow"
        case .coinbase:
            return "Coinbase Wallet"
        case .trust:
            return "Trust Wallet"
        case .zerion:
            return "Zerion"
        case .safe:
            return "Safe"
        case .uniswap:
            return "Uniswap Wallet"
        case .rabby:
            return "Rabby"
        }
    }
    
    var deepLinkScheme: String {
        switch self {
        case .metamask:
            return "metamask://"
        case .rainbow:
            return "rainbow://"
        case .trust:
            return "trust://"
        case .safe:
            return "safe://"
        case .uniswap:
            return "uniswap://"
        case .zerion:
            return "zerion://"
        case .coinbase:
            return "cbwallet://"
        case .rabby:
            return "rabby://"
        }
    }
    
    var walletConnectScheme: String {
        switch self {
        case .metamask:
            return "metamask://wc?uri="
        case .rainbow:
            return "rainbow://wc?uri="
        case .trust:
            return "trust://wc?uri="
        case .safe:
            return "safe://wc?uri="
        case .uniswap:
            return "uniswap://wc?uri="
        case .zerion:
            return "zerion://wc?uri="
        case .coinbase:
            return "cbwallet://wc?uri="
        case .rabby:
            return "rabby://wc?uri="
        }
    }
    
    var appStoreURL: URL? {
        switch self {
        case .metamask:
            return URL(string: "https://apps.apple.com/app/metamask/id1438144202")
        case .rainbow:
            return URL(string: "https://apps.apple.com/app/rainbow-ethereum-wallet/id1457119021")
        case .coinbase:
            return URL(string: "https://apps.apple.com/app/coinbase-wallet/id1278383455")
        case .trust:
            return URL(string: "https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409")
        case .zerion:
            return URL(string: "https://apps.apple.com/app/zerion-defi-portfolio/id1456732565")
        case .safe:
            return URL(string: "https://apps.apple.com/app/safe-wallet/id1515759131")
        case .uniswap:
            return URL(string: "https://apps.apple.com/app/uniswap-wallet/id6443944476")
        case .rabby:
            // Rabby wallet App Store URL - update if different
            return URL(string: "https://apps.apple.com/app/rabby-wallet/id6735348354")
        }
    }
    
    var iconName: String {
        switch self {
        case .metamask:
            return "m.circle.fill"  // MetaMask - use M for MetaMask
        case .rainbow:
            return "sparkles"  // Rainbow - sparkles for colorful
        case .coinbase:
            return "c.circle.fill"  // Coinbase
        case .trust:
            return "shield.fill"  // Trust Wallet
        case .zerion:
            return "z.circle.fill"  // Zerion
        case .safe:
            return "lock.shield.fill"  // Safe
        case .uniswap:
            return "arrow.triangle.2.circlepath"  // Uniswap
        case .rabby:
            return "r.circle.fill"  // Rabby
        }
    }
}
