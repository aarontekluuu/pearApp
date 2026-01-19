import Foundation

// MARK: - Health Response
/// API health check response
struct HealthResponse: Codable {
    let status: HealthStatus
    let timestamp: Date
    let version: String?
    let uptime: TimeInterval?
    let services: [String: ServiceStatus]?
    
    var isHealthy: Bool {
        status == .healthy
    }
}

// MARK: - Health Status
enum HealthStatus: String, Codable {
    case healthy = "healthy"
    case degraded = "degraded"
    case unhealthy = "unhealthy"
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Service Status
struct ServiceStatus: Codable {
    let status: HealthStatus
    let message: String?
    let lastCheck: Date?
}
