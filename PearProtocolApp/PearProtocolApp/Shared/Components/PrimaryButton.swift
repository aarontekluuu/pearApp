import SwiftUI

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var style: ButtonStyle = .primary
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
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
            case .primary:
                return Color(hex: "080807") // Dark text on primary green
            case .secondary, .destructive:
                return .white
            }
        }
    }
    
    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                HapticManager.shared.buttonPress()
                action()
            }
        }) {
            HStack(spacing: Constants.UI.spacingSM) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                        .scaleEffect(0.9)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.buttonHeight)
            .background(
                Group {
                    if isDisabled {
                        Color.backgroundSecondary
                    } else if style == .primary {
                        Color.pearPrimary
                    } else {
                        style.backgroundColor
                    }
                }
            )
            .foregroundColor(isDisabled ? .textTertiary : style.foregroundColor)
            .cornerRadius(Constants.UI.cornerRadius)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .disabled(isLoading || isDisabled)
        .buttonStyle(ScaleButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
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
            HapticManager.shared.lightTap()
            action()
        }) {
            HStack(spacing: Constants.UI.spacingSM) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.iconSecondary)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, Constants.UI.spacingMD + 4)
            .padding(.vertical, Constants.UI.spacingSM + 4)
            .background(Color.backgroundSecondary)
            .foregroundColor(.textPrimary)
            .cornerRadius(Constants.UI.cornerRadius)
        }
        .disabled(isLoading)
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    var size: CGFloat = Constants.UI.iconSizeLarge
    var backgroundColor: Color = .backgroundSecondary
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(.iconPrimary)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
        }
    }
}

// MARK: - Pill Button (for tags/filters)
struct PillButton: View {
    let title: String
    var isSelected: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, Constants.UI.spacingSM + 4)
                .padding(.vertical, Constants.UI.spacingXS + 2)
                .background(isSelected ? Color.pearPrimary : Color.backgroundSecondary)
                .foregroundColor(isSelected ? Color(hex: "080807") : .textSecondary)
                .cornerRadius(Constants.UI.cornerRadius)
        }
    }
}
