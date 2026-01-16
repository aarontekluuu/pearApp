# Pear Protocol iOS App - Agent Context

## Overview

This is a **SwiftUI iOS app** (iOS 17.0+) for Pear Protocol basket trading. The app enables crypto traders to create and execute multi-asset pair trades on Hyperliquid via the Pear Protocol API.

## Architecture

**Pattern**: MVVM + Clean Architecture

```
Views → ViewModels → Repositories → Services/APIs
```

### Key Design Decisions

1. **@StateObject for ViewModels**: All ViewModels are instantiated with `@StateObject` in their parent views
2. **Singleton Services**: `WalletService.shared`, `PearAPIService.shared`, `WebSocketService.shared`, `KeychainService.shared`
3. **Actor for API Service**: `PearAPIService` is an actor for thread-safe API calls
4. **@MainActor for UI State**: ViewModels and Repositories use `@MainActor` for UI state management
5. **Combine for Bindings**: WebSocket updates flow through Combine publishers

## Directory Structure

```
PearProtocolApp/
├── App/PearProtocolApp.swift        # Entry point, TabView, AppState
├── Core/
│   ├── Models/                      # Codable data models
│   ├── Services/                    # API, WebSocket, Keychain, Wallet
│   └── Repositories/                # Data layer abstraction
├── Features/                        # Feature modules (MVVM)
│   ├── Onboarding/
│   ├── BasketBuilder/
│   ├── Positions/
│   ├── Home/
│   └── Settings/
├── Shared/
│   ├── Components/                  # PrimaryButton, LoadingView, ErrorView
│   ├── Extensions/                  # Color+Theme, Double+Currency, String+Address
│   └── Utils/                       # Constants, NetworkMonitor
└── Resources/
    ├── Config.plist                 # API credentials (not in git)
    └── Assets.xcassets              # Colors, icons
```

## Core Models

| Model | Purpose |
|-------|---------|
| `Asset` | Tradeable asset (ticker, price, volume) |
| `Basket` | Trade configuration (legs, weights, size) |
| `BasketLeg` | Single asset in a basket (asset, direction, weight) |
| `Position` | Open/closed position with PnL |
| `PositionLeg` | Single leg within a position |
| `Trade` | Trade request/response models |
| `AgentWallet` | Delegated trading wallet |

## API Integration

**Base URL**: `https://api.pearprotocol.io`
**WebSocket**: `wss://api.pearprotocol.io/ws`

### Endpoints

| Endpoint | Method | Use |
|----------|--------|-----|
| `/agentWallet` | GET/POST | Agent wallet CRUD |
| `/activeAssets` | GET | Fetch tradeable assets |
| `/trade/execute` | POST | Execute basket trade |
| `/trade/close` | POST | Close position |
| `/positions` | GET | Fetch positions |
| `/tradeHistory` | GET | Trade history |

### WebSocket Channels
- `prices.<assetId>` - Real-time price updates
- `positions.<userId>` - Position updates
- `fills.<orderId>` - Trade fill notifications

### Authentication
```swift
headers.add(.authorization(bearerToken: token))
```

## Key Services

### PearAPIService (Actor)
- Alamofire-based HTTP client
- Retry logic with exponential backoff
- Error mapping to `PearAPIError`

### WalletService (@MainActor)
- WalletConnect v2 integration
- Session management
- Message signing
- Transaction submission

### WebSocketService (@MainActor)
- Starscream WebSocket client
- Auto-reconnect with exponential backoff
- Channel subscription management
- Combine publishers for updates

### KeychainService (@MainActor)
- KeychainAccess wrapper
- Stores: auth token, agent wallet, approval status

## UI Patterns

### Navigation
- 4-tab bottom navigation: Home, Build, Portfolio, Settings
- Sheet presentations for modals
- NavigationStack for hierarchical navigation

### Components
- `PrimaryButton` - Main CTA button with loading state
- `AssetRow` / `AssetIcon` - Asset display components
- `DirectionBadge` - Long/Short indicator
- `LoadingView` / `ErrorView` - State views
- `SwipeToConfirmButton` - Trade confirmation

### Theming
```swift
Color.pearPrimary    // Pear green
Color.pearProfit     // Green (#00D395)
Color.pearLoss       // Red (#FF4D4D)
Color.backgroundPrimary    // #0A0E27
Color.backgroundSecondary  // #1A1E3D
```

### Haptics
```swift
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.impactOccurred()
```

## User Flow

1. **Onboarding**: Welcome → Connect Wallet → Create Agent → Sign Approval → Approve Builder → Complete
2. **Trading**: Select Assets → Configure Weights → Set Size → Review → Swipe to Execute
3. **Management**: View Positions → Tap for Details → Close Position

## Configuration

API credentials in `Resources/Config.plist`:
```xml
<key>API_TOKEN</key>
<string>bearer_token_here</string>
<key>WALLET_CONNECT_PROJECT_ID</key>
<string>project_id_here</string>
```

Load via:
```swift
ConfigLoader.loadAPIToken()
ConfigLoader.loadWalletConnectProjectId()
```

## Constants

Key values in `Shared/Utils/Constants.swift`:
- `Constants.API.baseURL`
- `Constants.Trading.minPositionSize` (10 USDC)
- `Constants.Trading.maxBasketAssets` (10)
- `Constants.AgentWallet.expiryDays` (180)
- `Constants.StorageKeys.*` (Keychain keys)

## Dependencies

```swift
.package(url: "https://github.com/WalletConnect/WalletConnectSwiftV2", from: "1.0.0")
.package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0")
.package(url: "https://github.com/daltoniam/Starscream", from: "4.0.0")
.package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0")
.package(url: "https://github.com/argentlabs/web3.swift", from: "1.6.0")
```

## Common Tasks

### Adding a New Feature
1. Create folder in `Features/`
2. Add `Views/`, `ViewModels/`, `Components/`
3. Create ViewModel with `@MainActor` and `@Published` state
4. Create SwiftUI View with `@StateObject` for ViewModel

### Adding API Endpoint
1. Add endpoint constant in `Constants.API`
2. Add method in `PearAPIService`
3. Add request/response models in `Core/Models/`

### Adding New Asset Property
1. Update `Asset` model in `Core/Models/Asset.swift`
2. Update sample data
3. Update `AssetRow` display if needed

### Modifying Trade Flow
1. Update `BasketBuilderViewModel`
2. Modify `TradeExecuteRequest` if API changes
3. Update `TradeReviewView` for UI changes

## Error Handling

- API errors mapped to `PearAPIError` enum
- User-friendly messages via `errorDescription`
- Retry logic: 3 attempts, exponential backoff
- Network status via `NetworkMonitor.shared`

## Testing Notes

- Use `Asset.sampleAssets` for mock data
- `Position.samplePositions` for position mocks
- `#if DEBUG` blocks load sample data when API fails
- Test on iOS Simulator iPhone 15 Pro

## Security

- Private keys NEVER stored or transmitted
- Auth tokens in iOS Keychain
- WalletConnect for signing only
- Config.plist excluded from git
