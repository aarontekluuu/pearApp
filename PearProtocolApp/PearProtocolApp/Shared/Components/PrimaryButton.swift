import SwiftUI

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var style: ButtonStyle = .primary
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary:
                return .pearPrimary
            case .secondary:
                return .backgroundSecondary
            case .destructive:
                return .pearLoss
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .destructive:
                return .white
            case .secondary:
                return .white
            }
        }
    }
    
    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                triggerHaptic()
                action()
            }
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                        .scaleEffect(0.9)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if style == .primary && !isDisabled {
                        Color.primaryGradient
                    } else {
                        style.backgroundColor
                    }
                }
            )
            .foregroundColor(style.foregroundColor)
            .cornerRadius(Constants.UI.cornerRadius)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isLoading || isDisabled)
    }
    
    private func triggerHaptic() {
        guard Constants.UI.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            triggerHaptic()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.backgroundSecondary)
            .foregroundColor(.white)
            .cornerRadius(Constants.UI.cornerRadius)
        }
        .disabled(isLoading)
    }
    
    private func triggerHaptic() {
        guard Constants.UI.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    var size: CGFloat = 44
    var backgroundColor: Color = .backgroundSecondary
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            triggerHaptic()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
        }
    }
    
    private func triggerHaptic() {
        guard Constants.UI.hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Primary Button") {}
        PrimaryButton(title: "Loading...", isLoading: true) {}
        PrimaryButton(title: "Disabled", isDisabled: true) {}
        PrimaryButton(title: "Secondary", style: .secondary) {}
        PrimaryButton(title: "Destructive", style: .destructive) {}
        
        HStack {
            SecondaryButton(title: "Cancel", icon: "xmark") {}
            SecondaryButton(title: "Confirm", icon: "checkmark") {}
        }
        
        HStack {
            IconButton(icon: "plus") {}
            IconButton(icon: "minus") {}
            IconButton(icon: "xmark") {}
        }
    }
    .padding()
    .background(Color.backgroundPrimary)
}
