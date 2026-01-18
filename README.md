# Pear Protocol iOS App

A mobile-first iOS app that makes advanced pair/basket trading on Pear Protocol accessible to crypto-native traders through a simple UX.

## Features

- **Wallet Connection**: Connect via WalletConnect (MetaMask, Rainbow, Coinbase Wallet, Trust Wallet)
- **Agent Wallet System**: Delegated trading without sharing private keys
- **Custom Basket Builder**: Create multi-asset positions with custom weights and directions
- **One-Tap Execution**: Execute complex multi-leg trades with a single swipe
- **Real-Time PnL Tracking**: WebSocket-powered live position updates
- **Position Management**: View, monitor, and close positions

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/pear-protocol-ios.git
cd pear-protocol-ios
```

2. Open the project in Xcode:
```bash
open PearProtocolApp/PearProtocolApp.xcodeproj
```

3. Configure API credentials in `Resources/Config.plist`:
```xml
<key>API_TOKEN</key>
<string>your_api_token_here</string>
<key>WALLET_CONNECT_PROJECT_ID</key>
<string>your_walletconnect_project_id</string>
```

4. Build and run (⌘R)

## Architecture

The app follows **MVVM + Clean Architecture**:

```
┌─────────────────────────────────────────┐
│            SwiftUI Views                │
│  (BasketBuilderView, PositionsView)     │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│          ViewModels                     │
│  (BasketBuilderVM, PositionsVM)         │
│  - @Published state                     │
│  - User action handlers                 │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│          Repositories                   │
│  (PearRepository, WalletRepository)     │
│  - Data layer abstraction               │
└─────┬──────────────────────────┬────────┘
      │                          │
┌─────▼──────┐          ┌────────▼────────┐
│  API Layer │          │  Wallet Layer   │
│  (Pear API)│          │ (WalletConnect) │
└────────────┘          └─────────────────┘
```

## Project Structure

```
PearProtocolApp/
├── App/
│   └── PearProtocolApp.swift          # Main app entry point
├── Core/
│   ├── Models/                        # Data models
│   │   ├── Asset.swift
│   │   ├── Basket.swift
│   │   ├── Position.swift
│   │   ├── Trade.swift
│   │   └── AgentWallet.swift
│   ├── Services/                      # API and infrastructure
│   │   ├── PearAPIService.swift
│   │   ├── WalletService.swift
│   │   ├── WebSocketService.swift
│   │   └── KeychainService.swift
│   └── Repositories/                  # Data layer
│       ├── PearRepository.swift
│       └── WalletRepository.swift
├── Features/
│   ├── Onboarding/                    # Wallet connection flow
│   ├── BasketBuilder/                 # Basket creation
│   ├── Positions/                     # Position management
│   ├── Home/                          # Discovery screen
│   └── Settings/                      # App settings
├── Shared/
│   ├── Components/                    # Reusable UI components
│   ├── Extensions/                    # Swift extensions
│   └── Utils/                         # Utilities
└── Resources/
    ├── Assets.xcassets
    ├── Config.plist
    └── Info.plist
```

## API Integration

### Base URL
- Mainnet: `https://api.pearprotocol.io`
- WebSocket: `wss://api.pearprotocol.io/ws`

### Key Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/agentWallet` | GET/POST | Agent wallet management |
| `/activeAssets` | GET | List tradeable markets |
| `/trade/execute` | POST | Execute basket trade |
| `/positions` | GET | Fetch active positions |
| `/trade/close` | POST | Close position |

### Authentication
```
Authorization: Bearer <CLIENT_TOKEN>
Content-Type: application/json
```

## Dependencies

- **WalletConnectSwiftV2** - Wallet connection
- **Alamofire** - HTTP networking
- **Starscream** - WebSocket client
- **KeychainAccess** - Secure storage
- **web3.swift** - Ethereum utilities

## User Flow

1. **Connect Wallet** → Connect via WalletConnect
2. **Create Agent Wallet** → Pear creates a delegated trading wallet
3. **Approve Agent** → Sign message to approve the agent wallet
4. **Approve Builder Fee** → One-time fee approval (0.1%)
5. **Build Basket** → Select assets, set weights, configure trade
6. **Execute Trade** → Swipe to confirm execution
7. **Manage Positions** → Monitor and close positions

## Design System

### Colors
- Primary: Pear Green (`#94D133`)
- Profit: `#00D395`
- Loss: `#FF4D4D`
- Background Primary: `#0A0E27`
- Background Secondary: `#1A1E3D`

### Typography
- SF Pro (iOS system font)

### Interactions
- Haptic feedback on all actions
- Swipe-to-confirm for trades
- Pull-to-refresh on lists

## Development

### Running Tests
```bash
xcodebuild test -scheme PearProtocolApp -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Code Style
- SwiftLint for style enforcement
- MVVM pattern for all features
- Async/await for asynchronous code

## License

MIT License - see LICENSE file for details.

## Support

- Documentation: https://docs.pearprotocol.io
- Discord: https://discord.gg/pearprotocol
- Email: support@pearprotocol.io
