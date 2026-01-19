import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var message: String = "Loading..."
    var showBackground: Bool = true
    
    var body: some View {
        VStack(spacing: Constants.UI.spacingMD) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .pearPrimary))
                .scaleEffect(1.2)
            
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(showBackground ? Color.backgroundPrimary : Color.clear)
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    var isLoading: Bool
    var message: String = "Loading..."
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                
                VStack(spacing: Constants.UI.spacingMD) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .pearPrimary))
                        .scaleEffect(1.5)
                    
                    Text(message)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.textPrimary)
                }
                .padding(Constants.UI.spacingXL)
                .background(Color.backgroundSecondary)
                .cornerRadius(Constants.UI.cornerRadiusLarge)
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Shimmer Loading
struct ShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.backgroundSecondary.opacity(0.4),
                Color.backgroundTertiary.opacity(0.2),
                Color.backgroundSecondary.opacity(0.4)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(Rectangle())
        .offset(x: isAnimating ? 200 : -200)
        .animation(
            Animation.linear(duration: 1.5)
                .repeatForever(autoreverses: false),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Skeleton Row
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: Constants.UI.spacingSM + 4) {
            Circle()
                .fill(Color.backgroundTertiary)
                .frame(width: Constants.UI.iconSizeLarge, height: Constants.UI.iconSizeLarge)
            
            VStack(alignment: .leading, spacing: Constants.UI.spacingSM) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.backgroundTertiary)
                    .frame(width: 100, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.backgroundTertiary)
                    .frame(width: 60, height: 12)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: Constants.UI.spacingSM) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.backgroundTertiary)
                    .frame(width: 80, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.backgroundTertiary)
                    .frame(width: 50, height: 12)
            }
        }
        .padding(.vertical, Constants.UI.spacingSM + 4)
        .overlay(ShimmerView())
        .clipped()
    }
}

// MARK: - Pulsing Loader
struct PulsingLoader: View {
    @State private var isAnimating = false
    var color: Color = .pearPrimary
    var size: CGFloat = 12
    
    var body: some View {
        HStack(spacing: size * 0.5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Pull to Refresh Indicator
struct RefreshIndicator: View {
    var body: some View {
        HStack(spacing: Constants.UI.spacingSM) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .pearPrimary))
            
            Text("Refreshing...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }
}
