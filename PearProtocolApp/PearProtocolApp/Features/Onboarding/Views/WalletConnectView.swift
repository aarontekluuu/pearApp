import SwiftUI

// MARK: - Wallet Connect View
struct WalletConnectView: View {
    @StateObject private var viewModel = WalletViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - pure black to match pear icon
                Color.black
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
        .onAppear {
            // Inject appState into viewModel for bypass
            viewModel.appState = appState
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
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Logo and branding
            VStack(spacing: 16) {
                Image("pear")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                
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
                    .foregroundColor(.textPrimary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.textTertiary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Connect Wallet Content
struct ConnectWalletContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    @State private var showSkipConfirmation = false
    @State private var showingURIOptions = false
    @State private var copiedURI = false
    @State private var showingWalletSelection = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                
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
                
                // Show connection URI if wallet connection is in progress
                if let uri = viewModel.pairingURI, viewModel.isLoading {
                    VStack(spacing: 16) {
                        Text("Connection in Progress")
                            .font(.headline)
                            .foregroundColor(.pearPrimary)
                        
                        Text("The wallet app should open automatically. If it doesn't show a connection prompt, try:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Make sure your wallet app is unlocked")
                            Text("2. Check for notifications in your wallet")
                            Text("3. Look for 'Pending Connections' in wallet settings")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        
                        // Copy URI Button (for manual QR code scanning)
                        VStack(spacing: 8) {
                            Text("Or scan this QR code in your wallet:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                UIPasteboard.general.string = uri
                                copiedURI = true
                                
                                // Reset after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedURI = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: copiedURI ? "checkmark" : "doc.on.doc")
                                    Text(copiedURI ? "Copied!" : "Copy Connection Link")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(copiedURI ? .pearProfit : .pearPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.backgroundSecondary)
                                .cornerRadius(12)
                            }
                            
                            Text("Note: Paste this into a WalletConnect-compatible dApp browser, not a regular browser")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Connection status
                        if viewModel.connectionStage.isActive {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .pearPrimary))
                                    .scaleEffect(0.8)
                                Text(viewModel.connectionStage.displayMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                
                // Supported wallets - REMOVED
                // VStack(spacing: 12) {
                //     Text("Supported Wallets")
                //         .font(.subheadline)
                //         .foregroundColor(.secondary)
                //     
                //     HStack(spacing: 24) {
                //         WalletIcon(name: "MetaMask")
                //         WalletIcon(name: "Rainbow")
                //         WalletIcon(name: "Coinbase")
                //         WalletIcon(name: "Trust")
                //     }
                // }
                // .padding(.top, 16)
                
                Spacer(minLength: 40)
                
                // Connection status
                if viewModel.connectionStage.isActive && !viewModel.isWalletConnected {
                    VStack(spacing: 8) {
                        if case .waitingForApproval = viewModel.connectionStage {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .pearPrimary))
                        }
                        
                        Text(viewModel.connectionStage.displayMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                
                // Connection Success State
                // Only show "connected" confirmation if wallet was connected during THIS session
                // This prevents showing confirmation for restored sessions
                let shouldShowConnected = viewModel.isWalletConnected && !viewModel.isLoading && viewModel.hasConnectedInThisSession
                
                if shouldShowConnected {
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.pearProfit)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wallet Connected")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(viewModel.truncatedAddress)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.backgroundSecondary)
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        
                        PrimaryButton(title: "Continue") {
                            Task {
                                await viewModel.proceedFromConnection()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                    .onAppear {
                        DebugLogger.log(
                            location: "WalletConnectView.swift:313",
                            message: "Showing connected state UI",
                            data: [
                                "isWalletConnected": viewModel.isWalletConnected,
                                "isLoading": viewModel.isLoading,
                                "hasConnectedInThisSession": viewModel.hasConnectedInThisSession,
                                "currentStep": viewModel.currentStep.rawValue,
                                "connectedAddress": viewModel.connectedAddress ?? "nil"
                            ],
                            hypothesisId: "C"
                        )
                    }
                } else {
                    // Connect Button (only show when not connected)
                    VStack(spacing: 12) {
                        PrimaryButton(
                            title: showingURIOptions ? "Try Again" : "Select Wallet",
                            isLoading: viewModel.isLoading
                        ) {
                            showingWalletSelection = true
                        }
                        
                        // Skip button (always enabled for demos)
                        Button(action: {
                            showSkipConfirmation = true
                        }) {
                            Text("Skip for Demo")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textTertiary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .sheet(isPresented: $showingWalletSelection) {
                        WalletSelectionView(viewModel: viewModel)
                    }
                    .alert("Skip Wallet Connection?", isPresented: $showSkipConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Skip", role: .destructive) {
                            Task {
                                await viewModel.skipWalletConnection()
                                await viewModel.proceedFromConnection()
                            }
                        }
                    } message: {
                        Text("This will skip wallet connection for demo purposes. You'll use a test wallet address.")
                    }
                    .onChange(of: viewModel.isWalletConnected) {
                        let shouldShow = viewModel.isWalletConnected && !viewModel.isLoading && viewModel.hasConnectedInThisSession
                        DebugLogger.log(
                            location: "WalletConnectView.swift:295",
                            message: "Evaluating connected state UI condition",
                            data: [
                                "isWalletConnected": viewModel.isWalletConnected,
                                "isLoading": viewModel.isLoading,
                                "hasConnectedInThisSession": viewModel.hasConnectedInThisSession,
                                "shouldShowConnected": shouldShow,
                                "currentStep": viewModel.currentStep.rawValue,
                                "connectedAddress": viewModel.connectedAddress ?? "nil"
                            ],
                            hypothesisId: "C"
                        )
                    }
                    .onChange(of: viewModel.hasConnectedInThisSession) {
                        let shouldShow = viewModel.isWalletConnected && !viewModel.isLoading && viewModel.hasConnectedInThisSession
                        DebugLogger.log(
                            location: "WalletConnectView.swift:295",
                            message: "Evaluating connected state UI condition (hasConnectedInThisSession changed)",
                            data: [
                                "isWalletConnected": viewModel.isWalletConnected,
                                "isLoading": viewModel.isLoading,
                                "hasConnectedInThisSession": viewModel.hasConnectedInThisSession,
                                "shouldShowConnected": shouldShow,
                                "currentStep": viewModel.currentStep.rawValue,
                                "connectedAddress": viewModel.connectedAddress ?? "nil"
                            ],
                            hypothesisId: "C"
                        )
                    }
                }
            }
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
    @State private var showSkipConfirmation = false
    
    var body: some View {
        VStack(spacing: 32) {
            // Connected wallet indicator with disconnect option
            HStack {
                if let address = viewModel.connectedAddress {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.pearProfit)
                            .frame(width: 8, height: 8)
                        Text(address.truncatedAddress)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(20)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.disconnect()
                    }
                }) {
                    Text("Disconnect")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.pearLoss)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
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
            
            // Show different UI based on whether agent wallet is created
            if let agentAddress = viewModel.agentWalletAddress {
                // Agent wallet created - show confirmation
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.pearProfit)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Agent Wallet Created")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(agentAddress.truncatedAddress)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    
                    PrimaryButton(title: "Continue to Approval") {
                        viewModel.proceedToApproval()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            } else {
                // Agent wallet not created - show create button
                VStack(spacing: 12) {
                    PrimaryButton(
                        title: "Create Agent Wallet",
                        isLoading: viewModel.isLoading
                    ) {
                        Task {
                            await viewModel.createAgentWallet()
                        }
                    }
                    
                    // Skip button (always enabled for demos)
                    Button(action: {
                        showSkipConfirmation = true
                    }) {
                        Text("Skip for Demo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textTertiary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .alert("Skip Agent Wallet Creation?", isPresented: $showSkipConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Skip", role: .destructive) {
                        viewModel.skipAgentWalletCreation()
                        viewModel.proceedToApproval()
                    }
                } message: {
                    Text("This will skip agent wallet creation for demo purposes. You'll use a test agent wallet.")
                }
            }
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
                .foregroundColor(.pearPrimary.opacity(0.8))
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Sign Agent Approval Content
struct SignAgentApprovalContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    @State private var showSkipConfirmation = false
    
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
            
            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Sign Message",
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        await viewModel.signAgentApproval()
                    }
                }
                
                // Skip button (always enabled for demos)
                Button(action: {
                    showSkipConfirmation = true
                }) {
                    Text("Skip for Demo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .alert("Skip Agent Approval?", isPresented: $showSkipConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Skip", role: .destructive) {
                    viewModel.skipAgentApproval()
                }
            } message: {
                Text("This will skip agent approval signing for demo purposes. You'll proceed to builder approval.")
            }
        }
    }
}

// MARK: - Approve Builder Content
struct ApproveBuilderContentView: View {
    @ObservedObject var viewModel: WalletViewModel
    @State private var showSkipConfirmation = false
    
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
            
            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Approve Fee",
                    isLoading: viewModel.isLoading
                ) {
                    Task {
                        await viewModel.approveBuilderFee()
                    }
                }
                
                // Skip button (always enabled for demos)
                Button(action: {
                    showSkipConfirmation = true
                }) {
                    Text("Skip for Demo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .alert("Skip Builder Fee Approval?", isPresented: $showSkipConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Skip", role: .destructive) {
                    viewModel.skipBuilderApproval()
                }
            } message: {
                Text("This will skip builder fee approval for demo purposes. You'll complete onboarding.")
            }
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
                
                // Ensure WebSocket is connected after onboarding completes
                // This ensures real-time data is available immediately
                Task { @MainActor in
                    let webSocketService = WebSocketService.shared
                    if !webSocketService.isConnected {
                        print("🔵 [DEBUG] Onboarding complete - connecting WebSocket")
                        webSocketService.connect()
                    }
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
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.textTertiary)
        }
    }
}
