import SwiftUI

// MARK: - Error View
struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.pearLoss)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let retryAction = retryAction {
                SecondaryButton(title: "Try Again", icon: "arrow.clockwise") {
                    retryAction()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            if let actionTitle = actionTitle, let action = action {
                SecondaryButton(title: actionTitle) {
                    action()
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Inline Error Banner
struct ErrorBanner: View {
    let message: String
    var dismissAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.pearLoss)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            if let dismissAction = dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.pearLoss.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pearLoss.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Success Banner
struct SuccessBanner: View {
    let message: String
    var dismissAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.pearProfit)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer()
            
            if let dismissAction = dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.pearProfit.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pearProfit.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    var type: ToastType = .info
    
    enum ToastType {
        case info
        case success
        case error
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .pearProfit
            case .error: return .pearLoss
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.backgroundSecondary)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
}

#Preview {
    VStack(spacing: 24) {
        ErrorView(message: "Network connection failed") {
            print("Retry")
        }
        .frame(height: 250)
        
        EmptyStateView(
            icon: "tray",
            title: "No Positions",
            message: "You don't have any open positions yet",
            actionTitle: "Create Basket"
        ) {
            print("Action")
        }
        .frame(height: 250)
        
        ErrorBanner(message: "Failed to load positions") {
            print("Dismiss")
        }
        
        SuccessBanner(message: "Trade executed successfully") {
            print("Dismiss")
        }
        
        ToastView(message: "Position closed", type: .success)
    }
    .padding()
    .background(Color.backgroundPrimary)
}
