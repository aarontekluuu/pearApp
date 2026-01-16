import SwiftUI

@main
struct PearProtocolApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
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
    
    var isFullyOnboarded: Bool {
        isWalletConnected && isAgentApproved && isBuilderApproved
    }
}

// MARK: - Content View (Root)
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.isFullyOnboarded {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .animation(.easeInOut, value: appState.isFullyOnboarded)
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
            case .build: return "Build"
            case .portfolio: return "Portfolio"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .build: return "leaf.fill"
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
    }
}

// MARK: - Placeholder Views (will be replaced with actual implementations)
struct OnboardingFlowView: View {
    var body: some View {
        WalletConnectView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
