import Foundation
import SwiftUI
import Combine

// MARK: - Wallet ViewModel
@MainActor
final class WalletViewModel: ObservableObject {
    // MARK: - Published State
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var showError: Bool = false
    
    // Agent Wallet State
    @Published var agentWalletAddress: String?
    @Published var messageToSign: String?
    
    // MARK: - Dependencies
    private let walletService = WalletService.shared
    private let walletRepository = WalletRepository.shared
    private let keychainService = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var isWalletConnected: Bool {
        walletService.isConnected
    }
    
    var connectedAddress: String? {
        walletService.connectedAddress
    }
    
    var truncatedAddress: String {
        walletService.connectedAddress?.truncatedAddress ?? ""
    }
    
    var isAgentWalletApproved: Bool {
        walletRepository.agentWallet?.isApproved == true
    }
    
    var isBuilderApproved: Bool {
        walletRepository.isBuilderApproved
    }
    
    var isFullyOnboarded: Bool {
        isWalletConnected && isAgentWalletApproved && isBuilderApproved
    }
    
    // MARK: - Init
    init() {
        setupBindings()
        checkInitialState()
    }
    
    private func setupBindings() {
        walletService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if isConnected && self?.currentStep == .connectWallet {
                    self?.currentStep = .createAgentWallet
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkInitialState() {
        if isFullyOnboarded {
            currentStep = .complete
        } else if isWalletConnected && isAgentWalletApproved {
            currentStep = .approveBuilder
        } else if isWalletConnected {
            currentStep = .createAgentWallet
        } else {
            currentStep = .welcome
        }
    }
    
    // MARK: - Actions
    func startOnboarding() {
        currentStep = .connectWallet
    }
    
    func connectWallet() async {
        isLoading = true
        error = nil
        
        do {
            _ = try await walletService.connect()
            currentStep = .createAgentWallet
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func createAgentWallet() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await walletRepository.createAgentWallet()
            agentWalletAddress = response.agentWalletAddress
            messageToSign = response.messageToSign
            currentStep = .signAgentApproval
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func signAgentApproval() async {
        guard let message = messageToSign,
              let agentAddress = agentWalletAddress else {
            error = "Missing agent wallet data"
            showError = true
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let signature = try await walletService.signMessage(message)
            try await walletRepository.approveAgentWallet(signature: signature, agentWalletAddress: agentAddress)
            currentStep = .approveBuilder
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func approveBuilderFee() async {
        isLoading = true
        error = nil
        
        do {
            // Send builder approval transaction
            // This would typically call a contract method on Hyperliquid
            // For now, we'll simulate the approval
            
            // In production:
            // let txHash = try await walletService.sendTransaction(
            //     to: builderContractAddress,
            //     value: "0x0",
            //     data: approveBuilderCalldata
            // )
            
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            walletRepository.setBuilderApproved(true)
            currentStep = .complete
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    func disconnect() async {
        await walletService.disconnect()
        keychainService.clearAll()
        currentStep = .welcome
    }
    
    func dismissError() {
        showError = false
        error = nil
    }
}

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case connectWallet = 1
    case createAgentWallet = 2
    case signAgentApproval = 3
    case approveBuilder = 4
    case complete = 5
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Pear"
        case .connectWallet:
            return "Connect Wallet"
        case .createAgentWallet:
            return "Create Agent Wallet"
        case .signAgentApproval:
            return "Approve Agent"
        case .approveBuilder:
            return "Approve Builder Fee"
        case .complete:
            return "All Set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome:
            return "Trade ideas, not tokens"
        case .connectWallet:
            return "Connect your wallet to get started"
        case .createAgentWallet:
            return "Create a delegated trading wallet"
        case .signAgentApproval:
            return "Sign to approve the agent wallet"
        case .approveBuilder:
            return "One-time approval for trading fees"
        case .complete:
            return "You're ready to trade!"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome:
            return "leaf.fill"
        case .connectWallet:
            return "wallet.pass.fill"
        case .createAgentWallet:
            return "person.badge.key.fill"
        case .signAgentApproval:
            return "signature"
        case .approveBuilder:
            return "checkmark.seal.fill"
        case .complete:
            return "checkmark.circle.fill"
        }
    }
    
    var progress: Double {
        Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
}
