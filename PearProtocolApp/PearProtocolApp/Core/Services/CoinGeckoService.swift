import Foundation
import UIKit

// MARK: - CoinGecko Service
/// Service for fetching crypto icons and prices from CoinGecko API
@MainActor
public class SharedCoinGeckoService: ObservableObject {
    public static let shared = SharedCoinGeckoService()
    
    private let baseURL = "https://api.coingecko.com/api/v3"
    private var iconCache: [String: UIImage] = [:]
    private var priceCache: [String: CoinGeckoPrice] = [:]
    private var lastPriceFetch: Date?
    
    // Map common tickers to CoinGecko coin IDs
    private let tickerToCoinId: [String: String] = [
        "BTC": "bitcoin",
        "ETH": "ethereum",
        "USDC": "usd-coin",
        "USDT": "tether",
        "SOL": "solana",
        "MATIC": "matic-network",
        "ARB": "arbitrum",
        "AVAX": "avalanche-2",
        "LINK": "chainlink",
        "UNI": "uniswap",
        "AAVE": "aave",
        "OP": "optimism",
        "DOGE": "dogecoin",
        "SHIB": "shiba-inu",
        "LTC": "litecoin",
        "XRP": "ripple",
        "ADA": "cardano",
        "DOT": "polkadot",
        "ATOM": "cosmos",
        "NEAR": "near",
        "FTM": "fantom",
        "CRV": "curve-dao-token",
        "MKR": "maker",
        "SNX": "havven",
        "COMP": "compound-governance-token",
        "SUSHI": "sushi",
        "YFI": "yearn-finance",
        "1INCH": "1inch",
        "BAL": "balancer",
        "LDO": "lido-dao",
        "RPL": "rocket-pool",
        "GMX": "gmx",
        "DYDX": "dydx",
        "APE": "apecoin",
        "BLUR": "blur",
        "IMX": "immutable-x",
        "MANA": "decentraland",
        "SAND": "the-sandbox",
        "AXS": "axie-infinity",
        "GALA": "gala",
        "ENS": "ethereum-name-service",
        "LRC": "loopring",
        "ZRX": "0x",
        "PEPE": "pepe",
        "WLD": "worldcoin-wld",
        "SEI": "sei-network",
        "SUI": "sui",
        "APT": "aptos",
        "INJ": "injective-protocol",
        "TIA": "celestia",
        "STX": "blockstack",
        "FIL": "filecoin",
        "RENDER": "render-token",
        "FET": "fetch-ai",
        "RNDR": "render-token",
        "GRT": "the-graph",
        "OCEAN": "ocean-protocol",
        "AGIX": "singularitynet",
        "WIF": "dogwifcoin",
        "BONK": "bonk",
        "JUP": "jupiter-exchange-solana",
        "PYTH": "pyth-network",
        "JTO": "jito-governance-token",
        "TRX": "tron",
        "TON": "the-open-network",
        "KAS": "kaspa",
        "HBAR": "hedera-hashgraph",
        "VET": "vechain",
        "ICP": "internet-computer",
        "EGLD": "elrond-erd-2",
        "ALGO": "algorand",
        "XLM": "stellar",
        "EOS": "eos",
        "XTZ": "tezos",
        "FLOW": "flow",
        "MINA": "mina-protocol",
        "ROSE": "oasis-network",
        "KAVA": "kava",
        "ZEC": "zcash",
        "ETC": "ethereum-classic",
        "BCH": "bitcoin-cash",
        "BSV": "bitcoin-cash-sv",
        "XMR": "monero",
        "DASH": "dash",
        "NEO": "neo",
        "WAVES": "waves",
        "ZIL": "zilliqa",
        "QTUM": "qtum",
        "ONT": "ontology",
        "ICX": "icon",
        "IOTA": "iota",
        "XEM": "nem",
        "BTT": "bittorrent",
        "WIN": "winklink",
        "HOT": "holotoken",
        "CHZ": "chiliz",
        "ENJ": "enjincoin",
        "BAT": "basic-attention-token",
        "THETA": "theta-token",
        "TFUEL": "theta-fuel",
        "ONE": "harmony",
        "FTT": "ftx-token",
        "CRO": "crypto-com-chain",
        "HT": "huobi-token",
        "OKB": "okb",
        "LEO": "leo-token",
        "KCS": "kucoin-shares",
        "BNB": "binancecoin",
        "WBTC": "wrapped-bitcoin",
        "WETH": "weth",
        "stETH": "staked-ether",
        "rETH": "rocket-pool-eth",
        "cbETH": "coinbase-wrapped-staked-eth"
    ]
    
    private init() {}
    
    // MARK: - Icon Methods
    
    /// Get CoinGecko coin ID for a ticker
    func coinId(for ticker: String) -> String? {
        return tickerToCoinId[ticker.uppercased()]
    }
    
    /// Get icon URL for a ticker
    public func iconURL(for ticker: String) -> URL? {
        guard let coinId = coinId(for: ticker.uppercased()) else { return nil }
        // CoinGecko CDN format
        return URL(string: "https://assets.coingecko.com/coins/images/1/large/\(coinId).png")
    }
    
    /// Get cached icon
    public func getCachedIcon(for ticker: String) -> UIImage? {
        return iconCache[ticker.uppercased()]
    }
    
    /// Cache icon
    func cacheIcon(_ image: UIImage, for ticker: String) {
        iconCache[ticker.uppercased()] = image
    }
    
    /// Fetch icon from CoinGecko
    public func fetchIcon(for ticker: String) async -> UIImage? {
        let normalizedTicker = ticker.uppercased()
        
        // Check cache first
        if let cached = iconCache[normalizedTicker] {
            return cached
        }
        
        guard let coinId = coinId(for: normalizedTicker) else {
            // Try to search CoinGecko by symbol as fallback
            return await fetchIconBySymbol(normalizedTicker)
        }
        
        // Try direct CDN URL first (faster)
        if let directURL = URL(string: "https://assets.coingecko.com/coins/images/1/large/\(coinId).png") {
            do {
                let (imageData, response) = try await URLSession.shared.data(from: directURL)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let image = UIImage(data: imageData) {
                    iconCache[normalizedTicker] = image
                    return image
                }
            } catch {
                // Fall through to API fetch
            }
        }
        
        // Fallback: Fetch coin details to get the actual icon URL
        let url = URL(string: "\(baseURL)/coins/\(coinId)?localization=false&tickers=false&market_data=false&community_data=false&developer_data=false")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let coin = try JSONDecoder().decode(CoinGeckoCoinDetail.self, from: data)
            
            if let imageURLString = coin.image?.large ?? coin.image?.small ?? coin.image?.thumb,
               let imageURL = URL(string: imageURLString) {
                let (imageData, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: imageData) {
                    iconCache[normalizedTicker] = image
                    return image
                }
            }
        } catch {
            print("🔵 [CoinGecko] Failed to fetch icon for \(normalizedTicker): \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Fallback: Try to find icon by searching CoinGecko for the symbol
    private func fetchIconBySymbol(_ ticker: String) async -> UIImage? {
        // Try cryptoicons.org as fallback for unknown tokens
        let fallbackURL = URL(string: "https://cryptoicons.org/api/icon/\(ticker.lowercased())/200")!
        
        do {
            let (imageData, response) = try await URLSession.shared.data(from: fallbackURL)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let image = UIImage(data: imageData), image.size.width > 0 {
                iconCache[ticker] = image
                return image
            }
        } catch {
            // Ignore - will use fallback colored circle
        }
        
        return nil
    }
    
    // MARK: - Price Methods
    
    /// Fetch prices for multiple tickers
    public func fetchPrices(for tickers: [String]) async -> [String: CoinGeckoPrice] {
        // Map tickers to coin IDs
        var tickerToCoinIdMap: [String: String] = [:]
        var coinIds: [String] = []
        
        for ticker in tickers {
            let normalizedTicker = ticker.uppercased()
            if let coinId = self.coinId(for: normalizedTicker) {
                tickerToCoinIdMap[coinId] = normalizedTicker
                coinIds.append(coinId)
            }
        }
        
        guard !coinIds.isEmpty else {
            print("🔵 [CoinGecko] No valid coin IDs found for tickers")
            return [:]
        }
        
        // CoinGecko API: /simple/price
        let idsString = coinIds.joined(separator: ",")
        let urlString = "\(baseURL)/simple/price?ids=\(idsString)&vs_currencies=usd&include_24hr_vol=true&include_24hr_change=true"
        
        guard let url = URL(string: urlString) else { return [:] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode([String: CoinGeckoPriceResponse].self, from: data)
            
            var result: [String: CoinGeckoPrice] = [:]
            
            for (coinId, priceData) in response {
                if let ticker = tickerToCoinIdMap[coinId] {
                    result[ticker] = CoinGeckoPrice(
                        price: priceData.usd ?? 0,
                        priceChange24h: priceData.usd_24h_change ?? 0,
                        volume24h: priceData.usd_24h_vol ?? 0
                    )
                    priceCache[ticker] = result[ticker]
                }
            }
            
            lastPriceFetch = Date()
            print("🔵 [CoinGecko] ✅ Fetched prices for \(result.count) assets")
            return result
            
        } catch {
            print("🔵 [CoinGecko] ❌ Failed to fetch prices: \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// Get cached price
    public func getCachedPrice(for ticker: String) -> CoinGeckoPrice? {
        return priceCache[ticker.uppercased()]
    }
    
    // MARK: - Hyperliquid Price Methods
    
    /// Fetch prices, volume, and 24h change from Hyperliquid API (no API key needed)
    public func fetchHyperliquidPrices(for tickers: [String]) async -> [String: CoinGeckoPrice] {
        let urlString = "https://api.hyperliquid.xyz/info"
        guard let url = URL(string: urlString) else { return [:] }
        
        // Step 1: Get all mids (prices)
        var midsRequest = URLRequest(url: url)
        midsRequest.httpMethod = "POST"
        midsRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        midsRequest.httpBody = try? JSONSerialization.data(withJSONObject: ["type": "allMids"])
        
        // Step 2: Get meta data (includes 24h volume and price change)
        var metaRequest = URLRequest(url: url)
        metaRequest.httpMethod = "POST"
        metaRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        metaRequest.httpBody = try? JSONSerialization.data(withJSONObject: ["type": "meta"])
        
        do {
            // Fetch both in parallel
            async let midsData = URLSession.shared.data(for: midsRequest)
            async let metaData = URLSession.shared.data(for: metaRequest)
            
            let (midsResponse, _) = try await midsData
            let (metaResponse, _) = try await metaData
            
            // Parse mids (prices)
            guard let midsJson = try? JSONSerialization.jsonObject(with: midsResponse) as? [String: String] else {
                return [:]
            }
            
            // Parse meta (volume and price change)
            var metaMap: [String: [String: Any]] = [:]
            if let metaJson = try? JSONSerialization.jsonObject(with: metaResponse) as? [String: Any],
               let universe = metaJson["universe"] as? [[String: Any]] {
                for asset in universe {
                    if let name = asset["name"] as? String {
                        metaMap[name.uppercased()] = asset
                    }
                }
            }
            
            var prices: [String: CoinGeckoPrice] = [:]
            
            // Combine price data with volume/change data from meta
            for (ticker, priceString) in midsJson {
                guard let price = Double(priceString),
                      tickers.contains(where: { $0.uppercased() == ticker.uppercased() }) else {
                    continue
                }
                
                let normalizedTicker = ticker.uppercased()
                var volume24h: Double = 0
                var priceChange24h: Double = 0
                
                // Get volume and price change from meta if available
                if let meta = metaMap[normalizedTicker] {
                    // Try to extract volume - Hyperliquid meta may have different field names
                    if let volume = meta["volume24h"] as? Double {
                        volume24h = volume
                    } else if let volumeStr = meta["volume24h"] as? String, let vol = Double(volumeStr) {
                        volume24h = vol
                    } else if let volume = meta["volume"] as? Double {
                        volume24h = volume
                    } else if let volumeStr = meta["volume"] as? String, let vol = Double(volumeStr) {
                        volume24h = vol
                    }
                    
                    // Try to get 24h price change
                    if let change = meta["change24h"] as? Double {
                        priceChange24h = change
                    } else if let changeStr = meta["change24h"] as? String, let chg = Double(changeStr) {
                        priceChange24h = chg
                    } else if let prevPrice = meta["prevDayPx"] as? Double {
                        // Calculate change from previous day price
                        priceChange24h = ((price - prevPrice) / prevPrice) * 100
                    } else if let prevPriceStr = meta["prevDayPx"] as? String, let prevPrice = Double(prevPriceStr) {
                        priceChange24h = ((price - prevPrice) / prevPrice) * 100
                    }
                }
                
                prices[normalizedTicker] = CoinGeckoPrice(
                    price: price,
                    priceChange24h: priceChange24h,
                    volume24h: volume24h
                )
                priceCache[normalizedTicker] = prices[normalizedTicker]
            }
            
            // If we still don't have volume/change for some assets, fetch candles in batch
            // (This is a fallback - only for assets missing data)
            let missingDataAssets = prices.filter { $0.value.volume24h == 0 && $0.value.priceChange24h == 0 }.keys.prefix(10) // Limit to 10 to avoid too many requests
            
            for ticker in missingDataAssets {
                let normalizedTicker = ticker.uppercased()
                guard let currentPrice = prices[normalizedTicker]?.price else { continue }
                
                var candlesRequest = URLRequest(url: url)
                candlesRequest.httpMethod = "POST"
                candlesRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let candlesBody: [String: Any] = [
                    "type": "candleSnapshot",
                    "req": [
                        "coin": normalizedTicker,
                        "interval": "1d",
                        "n": 2
                    ]
                ]
                candlesRequest.httpBody = try? JSONSerialization.data(withJSONObject: candlesBody)
                
                if let (candlesData, _) = try? await URLSession.shared.data(for: candlesRequest),
                   let candlesJson = try? JSONSerialization.jsonObject(with: candlesData) as? [String: Any],
                   let data = candlesJson["data"] as? [[Any]], data.count >= 2 {
                    // candles format: [[timestamp, open, high, low, close, volume], ...]
                    if let yesterday = data[0] as? [Any], data.count > 1,
                       let today = data[1] as? [Any],
                       let yesterdayClose = yesterday[4] as? Double ?? (yesterday[4] as? String).flatMap(Double.init),
                       let todayVolume = today[5] as? Double ?? (today[5] as? String).flatMap(Double.init) {
                        // Update with calculated values
                        prices[normalizedTicker] = CoinGeckoPrice(
                            price: currentPrice,
                            priceChange24h: ((currentPrice - yesterdayClose) / yesterdayClose) * 100,
                            volume24h: todayVolume
                        )
                        priceCache[normalizedTicker] = prices[normalizedTicker]
                    }
                }
            }
            
            print("🔵 [Hyperliquid] ✅ Fetched prices for \(prices.count) assets (with volume/change data)")
            return prices
        } catch {
            print("🔵 [Hyperliquid] ❌ Failed to fetch prices: \(error.localizedDescription)")
        }
        
        return [:]
    }
}

// MARK: - CoinGecko Models

struct CoinGeckoCoinDetail: Codable {
    let id: String
    let symbol: String
    let name: String
    let image: CoinGeckoImage?
}

struct CoinGeckoImage: Codable {
    let thumb: String?
    let small: String?
    let large: String?
}

struct CoinGeckoPriceResponse: Codable {
    let usd: Double?
    let usd_24h_vol: Double?
    let usd_24h_change: Double?
}

public struct CoinGeckoPrice {
    public let price: Double
    public let priceChange24h: Double
    public let volume24h: Double
}


