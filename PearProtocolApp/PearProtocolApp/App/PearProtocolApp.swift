import SwiftUI
import WalletConnectSign
import WalletConnectPairing
import Combine

@main
struct PearProtocolApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    print("🔵 [DEBUG] App received deep link: \(url.absoluteString)")
                    handleDeepLink(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] 🔗 DEEP LINK RECEIVED")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] URL: \(url)")
        print("🔵 [DEBUG] Scheme: \(url.scheme ?? "nil")")
        print("🔵 [DEBUG] Host: \(url.host ?? "nil")")
        print("🔵 [DEBUG] Path: \(url.path)")
        print("🔵 [DEBUG] Query: \(url.query ?? "nil")")
        print("🔵 [DEBUG] ========================================")
        
        // WalletConnect SDK handles wc:// URLs internally
        // When MetaMask redirects back, the session should already be settled via relay
        // Check current session state
        let sessions = Sign.instance.getSessions()
        let pairings = Pair.instance.getPairings()
        print("🔵 [DEBUG] Current sessions: \(sessions.count)")
        print("🔵 [DEBUG] Current pairings: \(pairings.count)")
        
        if url.scheme == "pearprotocol" {
            print("🔵 [DEBUG] App callback received - wallet should have approved")
            // The session settlement should come through the relay
            // Give it a moment and check again
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
                let updatedSessions = Sign.instance.getSessions()
                print("🔵 [DEBUG] Sessions after delay: \(updatedSessions.count)")
                if let session = updatedSessions.first {
                    print("🔵 [DEBUG] ✅ Session found: \(session.topic)")
                }
            }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("🔵 [DEBUG] ========================================")
            print("🔵 [DEBUG] 📱 APP BECAME ACTIVE")
            print("🔵 [DEBUG] ========================================")
            // Check if we have a new session (user approved in wallet)
            let sessions = Sign.instance.getSessions()
            let pairings = Pair.instance.getPairings()
            print("🔵 [DEBUG] Sessions: \(sessions.count)")
            print("🔵 [DEBUG] Pairings: \(pairings.count)")
            
            if let session = sessions.first {
                print("🔵 [DEBUG] ✅ Active session found!")
                print("🔵 [DEBUG] Session topic: \(session.topic)")
                if let account = session.namespaces["eip155"]?.accounts.first {
                    print("🔵 [DEBUG] Account: \(account)")
                }
            }
            
            // Ensure WebSocket is connected when app becomes active
            // This handles cases where the connection was lost while app was backgrounded
            Task { @MainActor in
                let webSocketService = WebSocketService.shared
                if !webSocketService.isConnected && webSocketService.connectionState != .connecting {
                    print("🔵 [DEBUG] WebSocket not connected - reconnecting...")
                    webSocketService.connect()
                }
            }
            
            print("🔵 [DEBUG] ========================================")
            
        case .inactive:
            print("🔵 [DEBUG] App became inactive")
        case .background:
            print("🔵 [DEBUG] App went to background")
        @unknown default:
            break
        }
    }
}

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    @Published var isOnboarded: Bool = false
    @Published var isWalletConnected: Bool = false
    @Published var isAgentApproved: Bool = false
    @Published var isBuilderApproved: Bool = false
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        print("🔵 [DEBUG] AppState init started")
        
        // Bootstrap AuthService to restore tokens from Keychain
        AuthService.shared.bootstrap()
        
        // Check if user has completed onboarding previously
        // We reset to login state on fresh app launch - user must reconnect
        // This ensures wallet sessions are properly validated
        let keychainService = KeychainService.shared
        let storedStatus = keychainService.validateStoredData()
        
        print("🔵 [DEBUG] Stored status - hasConnectedWallet: \(storedStatus.hasConnectedWallet), hasAgentWallet: \(storedStatus.hasAgentWallet), isBuilderApproved: \(storedStatus.isBuilderApproved)")
        
        // Don't auto-restore onboarding state - require fresh login each app launch
        // The WalletService may have sessions but we want user to explicitly proceed
        isWalletConnected = false
        isAgentApproved = false
        isBuilderApproved = false
        
        print("🔵 [DEBUG] AppState init completed - isFullyOnboarded: \(isFullyOnboarded)")
        
        // Initialize WebSocket connection for market data (works without auth for public data)
        // Market data endpoint may not require authentication, so we can connect immediately
        Task { @MainActor in
            print("🔵 [DEBUG] Initializing WebSocket connection for market data...")
            WebSocketService.shared.connect()
        }
        
        // Listen for wallet disconnects and force app back to onboarding state
        WalletService.shared.$isConnected
            .removeDuplicates()
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.isWalletConnected = false
                self?.isAgentApproved = false
                self?.isBuilderApproved = false
            }
            .store(in: &cancellables)
        
        // Listen for authentication completion and reconnect WebSocket with auth token
        // This ensures WebSocket has the auth token for authenticated channels
        Task { @MainActor in
            // Monitor auth token changes via KeychainService
            // When token is set, WebSocketService.setAuthToken() will handle reconnection
            // We'll also connect WebSocket after onboarding completes
        }
    }
    
    var isFullyOnboarded: Bool {
        isWalletConnected && isAgentApproved && isBuilderApproved
    }
    
    // Call this to restore state after verifying wallet connection
    func restoreOnboardingState() {
        let keychainService = KeychainService.shared
        let storedStatus = keychainService.validateStoredData()
        
        if storedStatus.hasConnectedWallet && storedStatus.hasAgentWallet && !storedStatus.isAgentWalletExpired {
            isAgentApproved = true
        }
        
        if storedStatus.isBuilderApproved {
            isBuilderApproved = true
        }
    }
    
    // MARK: - Debug Bypass
    /// Bypasses onboarding state for development/demo purposes
    func bypassOnboardingState() {
        guard Constants.Debug.enableBypass else {
            print("⚠️ [DEBUG] Bypass disabled - not bypassing onboarding state")
            return
        }
        
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] 🚨 DEBUG BYPASS: AppState")
        print("🔵 [DEBUG] ========================================")
        print("🔵 [DEBUG] ⚠️ WARNING: This is a debug bypass")
        print("🔵 [DEBUG] ⚠️ DO NOT USE IN PRODUCTION")
        print("🔵 [DEBUG] ========================================")
        
        isWalletConnected = true
        isAgentApproved = true
        isBuilderApproved = true
        
        print("🔵 [DEBUG] ✅ AppState bypassed - isFullyOnboarded: \(isFullyOnboarded)")
        print("🔵 [DEBUG] ========================================")
    }
}

// MARK: - Content View (Root)
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        let _ = print("🔵 [DEBUG] ContentView body evaluated - isFullyOnboarded: \(appState.isFullyOnboarded)")
        
        return Group {
            if appState.isFullyOnboarded {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .animation(.easeInOut, value: appState.isFullyOnboarded)
    }
}

// MARK: - Tab Selection Environment
struct TabSelectionKey: EnvironmentKey {
    static var defaultValue: Binding<MainTabView.Tab> = .constant(.home)
}

extension EnvironmentValues {
    var tabSelection: Binding<MainTabView.Tab> {
        get { self[TabSelectionKey.self] }
        set { self[TabSelectionKey.self] = newValue }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab: Int, CaseIterable {
        case home = 0
        case build = 1
        case portfolio = 2
        case settings = 3
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .build: return "Trade"
            case .portfolio: return "Portfolio"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .build: return "arrow.triangle.2.circlepath"
            case .portfolio: return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)
            
            BasketBuilderView()
                .tabItem {
                    Label(Tab.build.title, systemImage: Tab.build.icon)
                }
                .tag(Tab.build)
            
            PositionsListView()
                .tabItem {
                    Label(Tab.portfolio.title, systemImage: Tab.portfolio.icon)
                }
                .tag(Tab.portfolio)
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(Color.pearPrimary)
        .environment(\.tabSelection, $selectedTab)
    }
}

// MARK: - Placeholder Views (will be replaced with actual implementations)
struct OnboardingFlowView: View {
    var body: some View {
        let _ = print("🔵 [DEBUG] OnboardingFlowView body evaluated - showing WalletConnectView")
        
        return WalletConnectView()
    }
}
