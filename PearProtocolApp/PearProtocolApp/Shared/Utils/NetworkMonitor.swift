import Foundation
import Network
import Combine
import SwiftUI

// MARK: - Network Monitor
/// Monitors network connectivity and provides real-time status updates
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // MARK: - Published State
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    @Published private(set) var isExpensive: Bool = false
    @Published private(set) var isConstrained: Bool = false
    
    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    nonisolated deinit {
        monitor.cancel()
    }
    
    // MARK: - Monitoring
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path: path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    private func updateConnectionStatus(path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wired
        } else {
            connectionType = .unknown
        }
    }
}

// MARK: - Network Status View Modifier
struct NetworkStatusModifier: ViewModifier {
    @StateObject private var networkMonitor: NetworkMonitor = {
        NetworkMonitor.shared
    }()
    @State private var showOfflineBanner = false
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showOfflineBanner {
                    OfflineBanner()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: networkMonitor.isConnected) { _, isConnected in
                withAnimation(.easeInOut) {
                    showOfflineBanner = !isConnected
                }
            }
    }
}

// MARK: - Offline Banner
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("No Internet Connection")
                .font(.subheadline)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.pearLoss)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .padding(.top, 8)
    }
}

// MARK: - View Extension
extension View {
    func networkStatus() -> some View {
        modifier(NetworkStatusModifier())
    }
}

// MARK: - Retry Handler
actor RetryHandler {
    private var retryCount = 0
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    
    init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }
    
    func shouldRetry() -> Bool {
        retryCount < maxRetries
    }
    
    func nextDelay() -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(retryCount))
        retryCount += 1
        return delay
    }
    
    func reset() {
        retryCount = 0
    }
    
    func execute<T>(
        operation: @escaping () async throws -> T,
        shouldRetry: @escaping (Error) -> Bool = { _ in true }
    ) async throws -> T {
        reset()
        
        while true {
            do {
                return try await operation()
            } catch {
                guard self.shouldRetry() && shouldRetry(error) else {
                    throw error
                }
                
                let delay = nextDelay()
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
}
