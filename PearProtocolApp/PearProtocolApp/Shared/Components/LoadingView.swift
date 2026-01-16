import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var message: String = "Loading..."
    var showBackground: Bool = true
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .pearPrimary))
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(Color.backgroundSecondary)
                .cornerRadius(16)
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
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.1),
                Color.gray.opacity(0.3)
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
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 12)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 12)
            }
        }
        .padding(.vertical, 12)
        .overlay(ShimmerView())
        .clipped()
    }
}

// MARK: - Pull to Refresh Indicator
struct RefreshIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .pearPrimary))
            
            Text("Refreshing...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        LoadingView()
            .frame(height: 200)
        
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonRow()
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
    .padding()
    .background(Color.backgroundPrimary)
}
