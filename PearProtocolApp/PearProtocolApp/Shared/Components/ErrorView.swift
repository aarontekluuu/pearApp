import SwiftUI

// MARK: - Error View
struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: Constants.UI.spacingMD + 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.pearLoss)
            
            VStack(spacing: Constants.UI.spacingSM) {
                Text("Something went wrong")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.textSecondary)
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
        VStack(spacing: Constants.UI.spacingMD + 4) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.iconTertiary)
            
            VStack(spacing: Constants.UI.spacingSM) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Constants.UI.spacingXL)
            }
            
            if let actionTitle = actionTitle, let action = action {
                SecondaryButton(title: actionTitle) {
                    action()
                }
                .padding(.top, Constants.UI.spacingSM)
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
        HStack(spacing: Constants.UI.spacingSM + 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.pearLoss)
                .font(.system(size: 18))
            
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
            
            Spacer()
            
            if let dismissAction = dismissAction {
                Button(action: {
                    HapticManager.shared.lightTap()
                    dismissAction()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.iconTertiary)
                }
            }
        }
        .padding(Constants.UI.cardPadding)
        .background(Color.pearLoss.opacity(0.12))
        .cornerRadius(Constants.UI.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .stroke(Color.pearLoss.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Success Banner
struct SuccessBanner: View {
    let message: String
    var dismissAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: Constants.UI.spacingSM + 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.pearProfit)
                .font(.system(size: 18))
            
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
            
            Spacer()
            
            if let dismissAction = dismissAction {
                Button(action: {
                    HapticManager.shared.lightTap()
                    dismissAction()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.iconTertiary)
                }
            }
        }
        .padding(Constants.UI.cardPadding)
        .background(Color.pearProfit.opacity(0.12))
        .cornerRadius(Constants.UI.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .stroke(Color.pearProfit.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            HapticManager.shared.success()
        }
    }
}

// MARK: - Warning Banner
struct WarningBanner: View {
    let message: String
    var dismissAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: Constants.UI.spacingSM + 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.pearWarning)
                .font(.system(size: 18))
            
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
            
            Spacer()
            
            if let dismissAction = dismissAction {
                Button(action: {
                    HapticManager.shared.lightTap()
                    dismissAction()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.iconTertiary)
                }
            }
        }
        .padding(Constants.UI.cardPadding)
        .background(Color.pearWarning.opacity(0.12))
        .cornerRadius(Constants.UI.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .stroke(Color.pearWarning.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            HapticManager.shared.warning()
        }
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
        case warning
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .pearPrimary
            case .success: return .pearProfit
            case .error: return .pearLoss
            case .warning: return .pearWarning
            }
        }
    }
    
    var body: some View {
        HStack(spacing: Constants.UI.spacingSM + 4) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .font(.system(size: 16))
            
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, Constants.UI.spacingMD + 4)
        .padding(.vertical, Constants.UI.spacingSM + 6)
        .background(Color.backgroundSecondary)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
}
