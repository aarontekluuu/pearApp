import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var walletService = WalletService.shared
    @StateObject private var walletRepository = WalletRepository.shared
    @State private var showDisconnectConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Wallet Section
                        WalletSection(
                            walletService: walletService,
                            showDisconnectConfirmation: $showDisconnectConfirmation
                        )
                        
                        // Agent Wallet Section
                        AgentWalletSection(repository: walletRepository)
                        
                        // Builder Fee Section
                        BuilderFeeSection(repository: walletRepository)
                        
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
                        await walletService.disconnect()
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Wallet")
                .font(.headline)
                .foregroundColor(.white)
            
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
                                .foregroundColor(.secondary)
                            
                            Text(address.truncatedAddress)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = address
                            triggerHaptic()
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let walletInfo = walletService.walletInfo {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ETH Balance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(walletInfo.formattedEthBalance)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("USDC Balance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(walletInfo.formattedUsdcBalance)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
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
                            .foregroundColor(.yellow)
                        
                        Text("Wallet not connected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
        }
    }
    
    private func triggerHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Agent Wallet Section
struct AgentWalletSection: View {
    @ObservedObject var repository: WalletRepository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agent Wallet")
                .font(.headline)
                .foregroundColor(.white)
            
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
                                .foregroundColor(.secondary)
                            
                            Text(agentWallet.truncatedAddress)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        StatusBadge(
                            text: agentWallet.statusDescription,
                            isPositive: agentWallet.isValid
                        )
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expires")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(agentWallet.formattedExpiry)
                                .font(.subheadline)
                                .foregroundColor(agentWallet.needsRefresh ? .yellow : .white)
                        }
                        
                        Spacer()
                        
                        if agentWallet.needsRefresh {
                            Button(action: {
                                // Refresh agent wallet
                            }) {
                                Text("Refresh")
                                    .font(.subheadline)
                                    .foregroundColor(.pearPrimary)
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        
                        Text("Agent wallet not configured")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Builder Fee Section
struct BuilderFeeSection: View {
    @ObservedObject var repository: WalletRepository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Builder Fee")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(repository.isBuilderApproved ? .pearProfit : .secondary)
                    .frame(width: 44, height: 44)
                    .background((repository.isBuilderApproved ? Color.pearProfit : Color.gray).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(repository.isBuilderApproved ? "Approved" : "Not Approved")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("0.1% Fee")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                Toggle(isOn: $hapticFeedback) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.pearPrimary)
                        
                        Text("Haptic Feedback")
                            .foregroundColor(.white)
                    }
                }
                .tint(.pearPrimary)
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
                .foregroundColor(.white)
            
            VStack(spacing: 0) {
                AboutRow(icon: "doc.text", title: "Terms of Service")
                Divider().padding(.leading, 56)
                AboutRow(icon: "hand.raised", title: "Privacy Policy")
                Divider().padding(.leading, 56)
                AboutRow(icon: "questionmark.circle", title: "Help & Support")
                Divider().padding(.leading, 56)
                
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.pearPrimary)
                        .frame(width: 24)
                    
                    Text("Version")
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .foregroundColor(.secondary)
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
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.pearPrimary)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    SettingsView()
}
