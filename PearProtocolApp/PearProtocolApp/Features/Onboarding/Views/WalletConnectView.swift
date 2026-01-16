import SwiftUI

// MARK: - Wallet Connect View
struct WalletConnectView: View {
    @StateObject private var viewModel = WalletViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    if viewModel.currentStep != .welcome && viewModel.currentStep != .complete {
                        OnboardingProgressView(step: viewModel.currentStep)
                            .padding(.top, 16)
                    }
                    
                    // Content
                    Group {
                        switch viewModel.currentStep {
                        case .welcome:
                            WelcomeContentView(viewModel: viewModel)
                        case .connectWallet:
                            ConnectWalletContentView(viewModel: viewModel)
                        case .createAgentWallet:
                            CreateAgentWalletContentView(viewModel: viewModel)
                        case .signAgentApproval:
                            SignAgentApprovalContentView(viewModel: viewModel)
                        case .approveBuilder:
                            ApproveBuilderContentView(viewModel: viewModel)
                        case .complete:
                            OnboardingCompleteContentView(viewModel: viewModel, appState: appState)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error ?? "An unexpected error occurred")
        }
    }
}

// MARK: - Progress View
struct OnboardingProgressView: View {
    let step: OnboardingStep
    
    var body: some View {
        VStack(spacing: 8) {
            // Step indicators
            HStack(spacing: 8) {
                ForEach(1..<5) { index in
                    Circle()
                        .fill(index <= step.rawValue ? Color.pearPrimary : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Text("Step \(step.rawValue) of 4")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

// MARK: - Welcome Content
struct WelcomeContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Logo and branding
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.primaryGradient)
                
                Text("Pear Protocol")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Trade ideas, not tokens")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Features
            VStack(spacing: 16) {
                FeatureRow(icon: "chart.pie.fill", title: "Build Custom Baskets", subtitle: "Create multi-asset positions with one tap")
                FeatureRow(icon: "arrow.triangle.swap", title: "Pair Trading", subtitle: "Go long and short simultaneously")
                FeatureRow(icon: "bolt.fill", title: "Instant Execution", subtitle: "Execute complex trades in seconds")
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // CTA Button
            PrimaryButton(title: "Get Started") {
                viewModel.startOnboarding()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.pearPrimary)
                .frame(width: 44, height: 44)
                .background(Color.pearPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Connect Wallet Content
struct ConnectWalletContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 60))
                .foregroundColor(.pearPrimary)
            
            VStack(spacing: 12) {
                Text("Connect Your Wallet")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Connect via WalletConnect to start trading")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Supported wallets
            VStack(spacing: 12) {
                Text("Supported Wallets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 24) {
                    WalletIcon(name: "MetaMask")
                    WalletIcon(name: "Rainbow")
                    WalletIcon(name: "Coinbase")
                    WalletIcon(name: "Trust")
                }
            }
            .padding(.top, 16)
            
            Spacer()
            
            // Connect Button
            PrimaryButton(
                title: "Connect Wallet",
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.connectWallet()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Wallet Icon
struct WalletIcon: View {
    let name: String
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.backgroundSecondary)
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Create Agent Wallet Content
struct CreateAgentWalletContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 60))
                .foregroundColor(.pearPrimary)
            
            VStack(spacing: 12) {
                Text("Create Agent Wallet")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("An agent wallet allows Pear to execute trades on your behalf without holding your funds.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Info card
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "shield.fill", text: "Non-custodial - you keep control")
                InfoRow(icon: "clock.fill", text: "Valid for 180 days")
                InfoRow(icon: "arrow.triangle.2.circlepath", text: "Can be revoked anytime")
            }
            .padding(20)
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
            .padding(.horizontal, 24)
            
            Spacer()
            
            PrimaryButton(
                title: "Create Agent Wallet",
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.createAgentWallet()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.pearPrimary)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Sign Agent Approval Content
struct SignAgentApprovalContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "signature")
                .font(.system(size: 60))
                .foregroundColor(.pearPrimary)
            
            VStack(spacing: 12) {
                Text("Sign to Approve")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Sign a message in your wallet to approve the agent wallet.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Agent wallet address
            if let address = viewModel.agentWalletAddress {
                VStack(spacing: 8) {
                    Text("Agent Wallet Address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(address.truncatedAddress)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.backgroundSecondary)
                        .cornerRadius(8)
                }
            }
            
            Spacer()
            
            PrimaryButton(
                title: "Sign Message",
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.signAgentApproval()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Approve Builder Content
struct ApproveBuilderContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.pearPrimary)
            
            VStack(spacing: 12) {
                Text("Approve Builder Fee")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("One-time approval to allow Pear to collect a small builder fee on trades.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Fee info
            VStack(spacing: 16) {
                HStack {
                    Text("Builder Fee")
                    Spacer()
                    Text("0.1%")
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                HStack {
                    Text("Network")
                    Spacer()
                    Text("Arbitrum")
                        .fontWeight(.semibold)
                }
            }
            .padding(20)
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
            .padding(.horizontal, 24)
            .foregroundColor(.white)
            
            Spacer()
            
            PrimaryButton(
                title: "Approve Fee",
                isLoading: viewModel.isLoading
            ) {
                Task {
                    await viewModel.approveBuilderFee()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Onboarding Complete Content
struct OnboardingCompleteContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    var appState: AppState
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.pearProfit)
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your wallet is connected and ready to trade.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Summary
            VStack(spacing: 12) {
                SummaryRow(icon: "checkmark.circle.fill", text: "Wallet Connected", value: viewModel.truncatedAddress)
                SummaryRow(icon: "checkmark.circle.fill", text: "Agent Wallet", value: "Active")
                SummaryRow(icon: "checkmark.circle.fill", text: "Builder Fee", value: "Approved")
            }
            .padding(20)
            .background(Color.backgroundSecondary)
            .cornerRadius(16)
            .padding(.horizontal, 24)
            
            Spacer()
            
            PrimaryButton(title: "Start Trading") {
                withAnimation {
                    appState.isWalletConnected = true
                    appState.isAgentApproved = true
                    appState.isBuilderApproved = true
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Summary Row
struct SummaryRow: View {
    let icon: String
    let text: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.pearProfit)
            
            Text(text)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    WalletConnectView()
        .environmentObject(AppState())
}
