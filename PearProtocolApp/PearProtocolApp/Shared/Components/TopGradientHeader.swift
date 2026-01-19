import SwiftUI

// MARK: - Top Gradient Header
/// A reusable gradient header component with shimmer animation
/// Extends to the top edge of the screen including status bar area
struct TopGradientHeader: View {
    /// Height of the gradient header (default: 100pt)
    var height: CGFloat = 100
    
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        ZStack(alignment: .top) {
            // Base gradient - fade from pear green to background
            LinearGradient(
                colors: [
                    Color.pearPrimary,
                    Color.backgroundPrimary
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .ignoresSafeArea(edges: .top)
            
            // Shimmer overlay
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.3),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 200, height: height)
            .offset(x: shimmerOffset)
            .blur(radius: 20)
            .ignoresSafeArea(edges: .top)
        }
        .frame(height: height)
        .onAppear {
            startShimmerAnimation()
        }
    }
    
    private func startShimmerAnimation() {
        withAnimation(
            Animation
                .linear(duration: 2.5)
                .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = UIScreen.main.bounds.width + 200
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.backgroundPrimary
            .ignoresSafeArea()
        
        VStack {
            TopGradientHeader()
            
            Spacer()
        }
    }
}
