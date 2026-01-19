import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var walletService = WalletService.shared
    @StateObject private var walletRepository = WalletRepository.shared
    @State private var showDisconnectConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                // Top gradient header
                TopGradientHeader()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Wallet Section
                        WalletSection(
                            walletService: walletService,
                            showDisconnectConfirmation: $showDisconnectConfirmation
                        )
                        
                        // Agent Wallet Section
                        AgentWalletSection(repository: walletRepository)
                        
                        // App Settings
                        AppSettingsSection()
                        
                        // About Section
                        AboutSection()
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Disconnect Wallet", isPresented: $showDisconnectConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    Task {
                        await walletService.clearAllConnections()
                    }
                }
            } message: {
                Text("Are you sure you want to disconnect your wallet? You'll need to reconnect to continue trading.")
            }
        }
    }
}

// MARK: - Wallet Section
struct WalletSection: View {
    @ObservedObject var walletService: WalletService
    @Binding var showDisconnectConfirmation: Bool
    @State private var showBalancesModal = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Wallet")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 16) {
                if walletService.isConnected, let address = walletService.connectedAddress {
                    HStack(spacing: 12) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.title2)
                            .foregroundColor(.pearPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.pearPrimary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Address")
                                .font(.caption)
                                .foregroundColor(.textTertiary)
                            
                            Text(address.truncatedAddress)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = address
                            HapticManager.shared.copy()
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.iconSecondary)
                        }
                    }
                    
                    Divider()
                        .background(Color.borderSubtle)
                    
                    // Balances Button
                    Button(action: {
                        HapticManager.shared.tap()
                        showBalancesModal = true
                    }) {
                        HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.pearPrimary)
                            Text("View Balances")
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.iconTertiary)
                        }
                        .font(.subheadline)
                    }
                    
                    Divider()
                        .background(Color.borderSubtle)
                    
                    Button(action: {
                        HapticManager.shared.tap()
                        showDisconnectConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Disconnect Wallet")
                        }
                        .font(.subheadline)
                        .foregroundColor(.pearLoss)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.pearWarning)
                        
                        Text("Wallet not connected")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
        }
        .sheet(isPresented: $showBalancesModal) {
            BalancesModalView(walletService: walletService)
        }
    }
}

// MARK: - Balances Modal View
struct BalancesModalView: View {
    @ObservedObject var walletService: WalletService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // USDC Balance Card
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                
                                Text("$")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("USDC")
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)
                                
                                Text("USD Coin")
                                    .font(.caption)
                                    .foregroundColor(.textTertiary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                            .background(Color.borderSubtle)
                        
                        HStack {
                            Text("Available Balance")
                                .font(.subheadline)
                                .foregroundColor(.textTertiary)
                            
                            Spacer()
                            
                            Text(walletService.walletInfo?.formattedUsdcBalance ?? "$0.00")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)
                        }
                    }
                    .padding()
                    .background(Color.backgroundSecondary)
                    .cornerRadius(16)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Balances")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.pearPrimary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Agent Wallet Section
struct AgentWalletSection: View {
    @ObservedObject var repository: WalletRepository
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agent Wallet")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 16) {
                if let agentWallet = repository.agentWallet {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Agent Address")
                                .font(.caption)
                                .foregroundColor(.textTertiary)
                            
                            Text(agentWallet.truncatedAddress)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.textPrimary)
                        }
                        
                        Spacer()
                        
                        StatusBadge(
                            text: agentWallet.statusDescription,
                            isPositive: agentWallet.isValid
                        )
                    }
                    
                    Divider()
                        .background(Color.borderSubtle)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expires")
                                .font(.caption)
                                .foregroundColor(.textTertiary)
                            
                            Text(agentWallet.formattedExpiry)
                                .font(.subheadline)
                                .foregroundColor(agentWallet.needsRefresh ? .pearWarning : .textPrimary)
                        }
                        
                        Spacer()
                        
                        if agentWallet.needsRefresh {
                            Button(action: {
                                HapticManager.shared.tap()
                                Task {
                                    isRefreshing = true
                                    await repository.checkAgentWalletStatus()
                                    isRefreshing = false
                                    HapticManager.shared.success()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if isRefreshing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text("Refresh")
                                        .font(.subheadline)
                                        .foregroundColor(.pearPrimary)
                                }
                            }
                            .disabled(isRefreshing)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.pearWarning)
                        
                        Text("Agent wallet not configured")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let isPositive: Bool
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isPositive ? Color.pearProfit : Color.yellow).opacity(0.2))
            .foregroundColor(isPositive ? .pearProfit : .yellow)
            .cornerRadius(8)
    }
}

// MARK: - App Settings Section
struct AppSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.pearPrimary)
                        .frame(width: 24)
                    
                    Text("Notifications")
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Text("Enabled")
                        .font(.subheadline)
                        .foregroundColor(.textTertiary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.iconTertiary)
                }
                .padding()
            }
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
        }
    }
}

// MARK: - About Section
struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 0) {
                AboutRow(icon: "doc.text", title: "Terms of Service", url: "https://pearprotocol.io/terms")
                Divider().background(Color.borderSubtle).padding(.leading, 56)
                AboutRow(icon: "hand.raised", title: "Privacy Policy", url: "https://pearprotocol.io/privacy")
                Divider().background(Color.borderSubtle).padding(.leading, 56)
                AboutRow(icon: "questionmark.circle", title: "Help & Support", url: "https://pearprotocol.io/help")
                Divider().background(Color.borderSubtle).padding(.leading, 56)
                
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.pearPrimary)
                        .frame(width: 24)
                    
                    Text("Version")
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .foregroundColor(.textTertiary)
                }
                .padding()
            }
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
        }
    }
}

// MARK: - About Row
struct AboutRow: View {
    let icon: String
    let title: String
    let url: String?
    
    init(icon: String, title: String, url: String? = nil) {
        self.icon = icon
        self.title = title
        self.url = url
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            if let urlString = url, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.pearPrimary)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.iconTertiary)
            }
            .padding()
        }
    }
}
