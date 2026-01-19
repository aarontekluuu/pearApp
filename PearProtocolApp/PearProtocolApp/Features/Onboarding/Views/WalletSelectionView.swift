import SwiftUI

// MARK: - Wallet Selection View
struct WalletSelectionView: View {
    @ObservedObject var viewModel: WalletViewModel
    @Environment(\.dismiss) var dismiss
    @State private var installedWallets: [WalletType] = []
    @State private var isLoadingWallets = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                if isLoadingWallets {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .pearPrimary))
                } else if installedWallets.isEmpty {
                    // No wallets installed
                    VStack(spacing: 16) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Wallets Found")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Please install a supported wallet app to continue")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 60)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Header
                            VStack(spacing: 8) {
                                Text("Select Wallet")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Choose a wallet to connect")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 8)
                            
                            // Only show installed wallets
                            ForEach(installedWallets) { wallet in
                                WalletCard(
                                    wallet: wallet,
                                    isInstalled: true
                                ) {
                                    handleWalletSelection(wallet)
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.pearPrimary)
                }
            }
        }
        .task {
            await loadInstalledWallets()
        }
    }
    
    private func loadInstalledWallets() async {
        isLoadingWallets = true
        installedWallets = await WalletService.shared.checkInstalledWallets()
        isLoadingWallets = false
    }
    
    private func handleWalletSelection(_ wallet: WalletType) {
        // All wallets shown are installed, proceed with connection
        DebugLogger.log(
            location: "WalletSelectionView.swift:90",
            message: "Wallet selected by user",
            data: [
                "walletName": wallet.displayName,
                "walletType": wallet.rawValue
            ],
            hypothesisId: "G"
        )
        
        viewModel.selectedWallet = wallet
        dismiss()
        Task {
            await viewModel.connectWallet()
        }
    }
}

// MARK: - Wallet Card
struct WalletCard: View {
    let wallet: WalletType
    let isInstalled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Wallet icon - use asset images when available
                ZStack {
                    Circle()
                        .fill(Color.backgroundSecondary)
                        .frame(width: 48, height: 48)
                    
                    // Use asset images for supported wallets
                    Group {
                        switch wallet {
                        case .metamask:
                            Image("metamask")
                                .resizable()
                                .scaledToFit()
                        case .coinbase:
                            Image("coinbase")
                                .resizable()
                                .scaledToFit()
                        case .rainbow:
                            Image("rainbow")
                                .resizable()
                                .scaledToFit()
                        case .trust:
                            Image("trustwallet")
                                .resizable()
                                .scaledToFit()
                        case .rabby:
                            Image("rabby")
                                .resizable()
                                .scaledToFit()
                        default:
                            // Fallback to system icon for wallets without asset images
                            Image(systemName: wallet.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(.pearPrimary)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                
                // Wallet info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(wallet.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if isInstalled {
                            Text("Installed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.pearProfit)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.pearProfit.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    if !isInstalled {
                        Text("Tap to install")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron or install icon
                if isInstalled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.pearPrimary)
                }
            }
            .padding(16)
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
