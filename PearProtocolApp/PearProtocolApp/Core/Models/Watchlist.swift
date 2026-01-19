import Foundation

// MARK: - Watchlist Item
/// Represents a basket/pair in the user's watchlist
struct WatchlistItem: Identifiable, Codable {
    let id: String
    let name: String
    let longAssets: [String] // Asset IDs
    let shortAssets: [String] // Asset IDs
    let createdAt: Date
    let lastViewedAt: Date?
    
    var displayName: String {
        let longNames = longAssets.joined(separator: "/")
        let shortNames = shortAssets.joined(separator: "/")
        return "\(longNames) vs \(shortNames)"
    }
}

// MARK: - Toggle Watchlist Request
struct ToggleWatchlistRequest: Codable {
    let longAssets: [String]
    let shortAssets: [String]
    
    init(longAssets: [String], shortAssets: [String]) {
        self.longAssets = longAssets
        self.shortAssets = shortAssets
    }
}

// MARK: - Toggle Watchlist Response
struct ToggleWatchlistResponse: Codable {
    let success: Bool
    let action: WatchlistAction // "added" or "removed"
    let watchlistItem: WatchlistItem?
    let message: String?
}

// MARK: - Watchlist Action
enum WatchlistAction: String, Codable {
    case added = "ADDED"
    case removed = "REMOVED"
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Watchlist Response
struct WatchlistResponse: Codable {
    let items: [WatchlistItem]
    let totalCount: Int
}
