import Foundation
import Alamofire

// MARK: - Pear API Service
/// Main API client for Pear Protocol backend
actor PearAPIService {
    static let shared = PearAPIService()
    
    private let session: Session
    private let baseURL: String
    private var authToken: String?
    
    private init() {
        self.baseURL = Constants.API.baseURL
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Constants.API.requestTimeout
        configuration.timeoutIntervalForResource = Constants.API.resourceTimeout
        
        self.session = Session(configuration: configuration)
        
        // Load token from config
        self.authToken = ConfigLoader.loadAPIToken()
    }
    
    // MARK: - Configuration
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    // MARK: - Headers
    private var headers: HTTPHeaders {
        var headers: HTTPHeaders = [
            .contentType("application/json"),
            .accept("application/json")
        ]
        
        if let token = authToken {
            headers.add(.authorization(bearerToken: token))
        }
        
        return headers
    }
    
    // MARK: - Agent Wallet Endpoints
    func getAgentWalletStatus(userAddress: String) async throws -> AgentWalletStatusResponse {
        let url = "\(baseURL)\(Constants.API.agentWallet)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                parameters: ["userAddress": userAddress],
                headers: self.headers
            )
            .validate()
            .serializingDecodable(AgentWalletStatusResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func createAgentWallet(request: AgentWalletCreateRequest) async throws -> AgentWalletCreateResponse {
        let url = "\(baseURL)\(Constants.API.agentWallet)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(AgentWalletCreateResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func approveAgentWallet(request: AgentWalletApproveRequest) async throws -> AgentWalletApproveResponse {
        let url = "\(baseURL)\(Constants.API.agentWallet)/approve"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(AgentWalletApproveResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Active Assets
    func fetchActiveAssets() async throws -> ActiveAssetsResponse {
        let url = "\(baseURL)\(Constants.API.activeAssets)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(ActiveAssetsResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Trading
    func executeTrade(request: TradeExecuteRequest) async throws -> TradeExecuteResponse {
        let url = "\(baseURL)\(Constants.API.tradeExecute)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(TradeExecuteResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func closePosition(request: ClosePositionRequest) async throws -> ClosePositionResponse {
        let url = "\(baseURL)\(Constants.API.tradeClose)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(ClosePositionResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Positions
    func fetchPositions(agentWalletAddress: String) async throws -> PositionsResponse {
        let url = "\(baseURL)\(Constants.API.positions)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                parameters: ["agentWallet": agentWalletAddress],
                headers: self.headers
            )
            .validate()
            .serializingDecodable(PositionsResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Trade History
    func fetchTradeHistory(
        agentWalletAddress: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> TradeHistoryResponse {
        let url = "\(baseURL)\(Constants.API.tradeHistory)"
        
        let parameters: [String: Any] = [
            "agentWallet": agentWalletAddress,
            "limit": limit,
            "offset": offset
        ]
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                parameters: parameters,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(TradeHistoryResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - JSON Decoder
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    
    // MARK: - Retry Logic
    private func withRetry<T>(
        maxAttempts: Int = Constants.API.maxRetryAttempts,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on client errors (4xx)
                if let afError = error as? AFError,
                   case .responseValidationFailed(let reason) = afError,
                   case .unacceptableStatusCode(let code) = reason,
                   (400..<500).contains(code) {
                    throw PearAPIError.from(statusCode: code, message: nil)
                }
                
                // Exponential backoff
                if attempt < maxAttempts - 1 {
                    let delay = Constants.API.retryBaseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? PearAPIError.unknown
    }
}

// MARK: - API Errors
enum PearAPIError: Error, LocalizedError {
    case unauthorized
    case invalidRequest(String?)
    case rateLimited
    case serverError
    case serviceUnavailable
    case networkError
    case decodingError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please reconnect wallet."
        case .invalidRequest(let message):
            return message ?? "Invalid request. Please check your input."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .serverError:
            return "Pear Protocol service unavailable. Try again."
        case .serviceUnavailable:
            return "Trading temporarily unavailable."
        case .networkError:
            return "Network connection error. Check your internet."
        case .decodingError:
            return "Unexpected response from server."
        case .unknown:
            return "An unexpected error occurred."
        }
    }
    
    static func from(statusCode: Int, message: String?) -> PearAPIError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 400:
            return .invalidRequest(message)
        case 429:
            return .rateLimited
        case 500:
            return .serverError
        case 503:
            return .serviceUnavailable
        default:
            return .unknown
        }
    }
}
