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

        self.authToken = nil
    }
    
    // MARK: - Configuration
    func setAuthToken(_ token: String?) {
        // #region agent log
        let hasTokenBefore = authToken != nil
        // #endregion
        
        if let token, !token.isEmpty {
            self.authToken = token
            // #region agent log
            print("🟡 [HYPO-C] PearAPIService.setAuthToken - token SET, length: \(token.count)")
            // #endregion
        } else {
            self.authToken = nil
            // #region agent log
            print("🟡 [HYPO-C] PearAPIService.setAuthToken - token CLEARED")
            // #endregion
        }
        
        // #region agent log
        print("🟡 [HYPO-C] PearAPIService.setAuthToken - hasTokenBefore: \(hasTokenBefore), hasTokenAfter: \(self.authToken != nil)")
        // #endregion
    }
    
    // MARK: - Headers
    private var headers: HTTPHeaders {
        var headers: HTTPHeaders = [
            .contentType("application/json"),
            .accept("application/json")
        ]
        
        if let token = authToken {
            headers.add(.authorization(bearerToken: token))
            // #region agent log
            print("🟡 [HYPO-C] headers computed - auth token ADDED to headers, length: \(token.count)")
            // #endregion
        } else {
            // #region agent log
            print("🟡 [HYPO-C] headers computed - NO auth token in headers")
            // #endregion
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
        print("[API] ========================================")
        print("[API] createAgentWallet() - ENTRY POINT")
        print("[API] ========================================")
        
        // API spec: POST /agentWallet (camelCase) - requires authentication
        let url = "\(baseURL)\(Constants.API.agentWallet)"
        
        // #region agent log
        let hasToken = authToken != nil
        let tokenLength = authToken?.count ?? 0
        print("🟡 [HYPO-A,C] PearAPIService.createAgentWallet START - url: \(url), userWallet: \(request.userWalletAddress), hasAuthToken: \(hasToken), tokenLength: \(tokenLength)")
        // #endregion
        
        print("[API] Request being constructed:")
        print("[API]   - URL: \(url)")
        print("[API]   - Method: POST")
        print("[API]   - userWalletAddress: \(request.userWalletAddress)")
        print("[API]   - hasAuthToken: \(hasToken)")
        print("[API]   - tokenLength: \(tokenLength)")
        
        // Log headers
        print("[API] Headers:")
        let currentHeaders = self.headers
        for header in currentHeaders {
            if header.name.lowercased() == "authorization" {
                print("[API]   - \(header.name): Bearer [REDACTED - length: \(tokenLength)]")
            } else {
                print("[API]   - \(header.name): \(header.value)")
            }
        }
        
        // Log request body
        if let jsonData = try? JSONEncoder().encode(request),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[API] Request body: \(jsonString)")
        } else {
            print("[API] Request body: [Failed to encode]")
        }
        
        print("[API] About to make HTTP request...")
        
        return try await withRetry {
            print("[API] Inside withRetry closure - making request...")
            print("[API] Creating Alamofire request object...")
            
            let requestStartTime = Date()
            let dataRequest = self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            print("[API] Request object created - starting serialization...")
            print("[API] Network request initiated - task may continue in background")
            
            let response = await dataRequest
                .validate()
                .serializingDecodable(AgentWalletCreateResponse.self, decoder: self.decoder)
                .response
            
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            print("[API] Request serialization completed in \(requestDuration)s")
            print("[API] Response object received - checking status...")
            print("[API] Network request task should be complete now")
            
            print("[API] ========================================")
            print("[API] Response received")
            print("[API] ========================================")
            
            // Log response details
            if let httpResponse = response.response {
                print("[API] Response status code: \(httpResponse.statusCode)")
                print("[API] Response headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("[API]   - \(key): \(value)")
                }
            } else {
                print("[API] ⚠️ No HTTP response object")
            }
            
            // Log response body
            if let data = response.data {
                print("[API] Response body length: \(data.count) bytes")
                if let bodyString = String(data: data, encoding: .utf8) {
                    print("[API] Response body: \(bodyString)")
                } else {
                    print("[API] Response body: [Not UTF-8 string]")
                }
            } else {
                print("[API] ⚠️ No response data")
            }
            
            // Check for 401 - this means authentication is required
            if let statusCode = response.response?.statusCode, statusCode == 401 {
                print("[API] ========================================")
                print("[API] ❌ 401 UNAUTHORIZED")
                print("[API] ========================================")
                print("[API] Authentication is required")
                // #region agent log
                print("🟡 [HYPO-C] createAgentWallet returned 401 - authentication required")
                // #endregion
                throw PearAPIError.unauthorized
            }
            
            // Check for other errors
            if let error = response.error {
                print("[API] ========================================")
                print("[API] ❌ Response error detected")
                print("[API] ========================================")
                print("[API] Error type: \(type(of: error))")
                print("[API] Error description: \(error.localizedDescription)")
                print("[API] Full error: \(error)")
                
                // error is already AFError in this context
                print("[API] AFError details:")
                print("[API]   - responseCode: \(error.responseCode?.description ?? "nil")")
                print("[API]   - underlyingError: \(error.underlyingError?.localizedDescription ?? "nil")")
                
                throw error
            }
            
            guard let data = response.data else {
                print("[API] ========================================")
                print("[API] ❌ No response data")
                print("[API] ========================================")
                throw PearAPIError.unknown
            }
            
            print("[API] Attempting to decode response...")
            // #region agent log
            if let responseString = String(data: data, encoding: .utf8) {
                print("🟡 [HYPO-AGENT-WALLET] Raw API response: \(responseString)")
            }
            // #endregion
            do {
                let decodedResponse = try self.decoder.decode(AgentWalletCreateResponse.self, from: data)
                print("[API] ========================================")
                print("[API] ✅ Decoding SUCCESS")
                print("[API] ========================================")
                print("[API] Decoded response:")
                print("[API]   - agentWalletAddress: \(decodedResponse.agentWalletAddress)")
                print("[API]   - messageToSign length: \(decodedResponse.messageToSign.count)")
                print("[API]   - expiresAt: \(decodedResponse.expiresAt?.description ?? "nil")")
                print("[API]   - nonce: \(decodedResponse.nonce ?? "nil")")
                print("[API]   - hasResolvedAuthToken: \(decodedResponse.resolvedAuthToken != nil)")
                // #region agent log
                print("🟡 [HYPO-AGENT-WALLET] ✅ Decoding SUCCESS - agentWalletAddress: \(decodedResponse.agentWalletAddress)")
                // #endregion
                return decodedResponse
            } catch {
                print("[API] ========================================")
                print("[API] ❌ Decoding FAILED")
                print("[API] ========================================")
                print("[API] Decoding error type: \(type(of: error))")
                print("[API] Decoding error description: \(error.localizedDescription)")
                print("[API] Full decoding error: \(error)")
                throw error
            }
        }
    }
    
    func approveAgentWallet(request: AgentWalletApproveRequest) async throws -> AgentWalletApproveResponse {
        let url = "\(baseURL)\(Constants.API.agentWallet)/approve"
        
        // #region agent log
        print("🟡 [HYPO-APPROVE] ========================================")
        print("🟡 [HYPO-APPROVE] approveAgentWallet() - ENTRY POINT")
        print("🟡 [HYPO-APPROVE] ========================================")
        print("🟡 [HYPO-APPROVE] URL: \(url)")
        print("🟡 [HYPO-APPROVE] Method: POST")
        print("🟡 [HYPO-APPROVE] Request:")
        print("🟡 [HYPO-APPROVE]   - agentWalletAddress: \(request.agentWalletAddress)")
        print("🟡 [HYPO-APPROVE]   - userWalletAddress: \(request.userWalletAddress)")
        print("🟡 [HYPO-APPROVE]   - signature length: \(request.signature.count)")
        print("🟡 [HYPO-APPROVE]   - hasAuthToken: \(self.authToken != nil)")
        print("🟡 [HYPO-APPROVE]   - tokenLength: \(self.authToken?.count ?? 0)")
        // #endregion
        
        return try await withRetry {
            let dataTask = self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .serializingData()
            
            let response = await dataTask.response
            let statusCode = response.response?.statusCode ?? -1
            let data = response.data ?? Data()
            
            // #region agent log
            print("🟡 [HYPO-APPROVE] Response received:")
            print("🟡 [HYPO-APPROVE]   - Status code: \(statusCode)")
            print("🟡 [HYPO-APPROVE]   - Data length: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🟡 [HYPO-APPROVE]   - Response body: \(responseString)")
            }
            // #endregion
            
            // Check for 404 specifically
            if statusCode == 404 {
                print("🟡 [HYPO-APPROVE] ❌ 404 NOT FOUND - endpoint may not exist")
                print("🟡 [HYPO-APPROVE] Attempted URL: \(url)")
                print("🟡 [HYPO-APPROVE] Possible fixes:")
                print("🟡 [HYPO-APPROVE]   1. Check if endpoint should be /agent-wallet/approve (kebab-case)")
                print("🟡 [HYPO-APPROVE]   2. Check if endpoint should be /agentWallet/approval (different word)")
                print("🟡 [HYPO-APPROVE]   3. Check if endpoint should be PUT/PATCH instead of POST")
                throw PearAPIError.notFound
            }
            
            // Validate status code
            guard (200...299).contains(statusCode) else {
                if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorBody["message"] as? String {
                    throw PearAPIError.invalidRequest(message)
                }
                throw PearAPIError.serverError
            }
            
            // Decode response
            do {
                return try self.decoder.decode(AgentWalletApproveResponse.self, from: data)
            } catch {
                print("🟡 [HYPO-APPROVE] ❌ Decoding failed: \(error)")
                throw PearAPIError.decodingError
            }
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
    
    // MARK: - Market Data
    func fetchMarketData() async throws -> MarketDataResponse {
        let url = "\(baseURL)\(Constants.API.marketData)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(MarketDataResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Trading
    func executeTrade(request: TradeExecuteRequest) async throws -> TradeExecuteResponse {
        let url = "\(baseURL)\(Constants.API.tradeExecute)"
        
        print("[API] ========================================")
        print("[API] executeTrade() - ENTRY POINT")
        print("[API] ========================================")
        print("[API] URL: \(url)")
        print("[API] Method: POST")
        
        // Log request details
        print("[API] Request details:")
        print("[API]   - slippage: \(request.slippage)")
        print("[API]   - executionType: \(request.executionType)")
        print("[API]   - leverage: \(request.leverage)")
        print("[API]   - usdValue: \(request.usdValue)")
        print("[API]   - longAssets count: \(request.longAssets?.count ?? 0)")
        print("[API]   - shortAssets count: \(request.shortAssets?.count ?? 0)")
        print("[API]   - hasStopLoss: \(request.stopLoss != nil)")
        print("[API]   - hasTakeProfit: \(request.takeProfit != nil)")
        print("[API]   - hasAuthToken: \(authToken != nil)")
        print("[API]   - tokenLength: \(authToken?.count ?? 0)")
        
        // Log full request JSON
        if let jsonData = try? JSONEncoder().encode(request),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[API] Request JSON: \(jsonString)")
        } else {
            print("[API] Request JSON: [Failed to encode]")
        }
        
        // Log headers
        print("[API] Headers:")
        let currentHeaders = self.headers
        for header in currentHeaders {
            if header.name.lowercased() == "authorization" {
                print("[API]   - \(header.name): Bearer [REDACTED - length: \(authToken?.count ?? 0)]")
            } else {
                print("[API]   - \(header.name): \(header.value)")
            }
        }
        
        print("[API] About to make HTTP request...")
        
        return try await withRetry {
            print("[API] Inside withRetry closure - making request...")
            
            let requestStartTime = Date()
            let dataRequest = self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            
            let response = await dataRequest
                .validate()
                .serializingDecodable(TradeExecuteResponse.self, decoder: self.decoder)
                .response
            
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            print("[API] Request completed in \(requestDuration)s")
            
            print("[API] ========================================")
            print("[API] Response received")
            print("[API] ========================================")
            
            // Log response details
            if let httpResponse = response.response {
                print("[API] Response status code: \(httpResponse.statusCode)")
                print("[API] Response headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("[API]   - \(key): \(value)")
                }
            } else {
                print("[API] ⚠️ No HTTP response object")
            }
            
            // Log response body
            if let data = response.data {
                print("[API] Response body length: \(data.count) bytes")
                if let bodyString = String(data: data, encoding: .utf8) {
                    print("[API] Response body: \(bodyString)")
                } else {
                    print("[API] Response body: [Not UTF-8 string]")
                }
            } else {
                print("[API] ⚠️ No response data")
            }
            
            // Check for errors
            if let error = response.error {
                print("[API] ========================================")
                print("[API] ❌ Response error detected")
                print("[API] ========================================")
                print("[API] Error type: \(type(of: error))")
                print("[API] Error description: \(error.localizedDescription)")
                print("[API] Full error: \(error)")
                
                if let afError = error as? AFError {
                    print("[API] AFError details:")
                    print("[API]   - responseCode: \(afError.responseCode?.description ?? "nil")")
                    print("[API]   - underlyingError: \(afError.underlyingError?.localizedDescription ?? "nil")")
                }
                
                throw error
            }
            
            guard let data = response.data else {
                print("[API] ========================================")
                print("[API] ❌ No response data")
                print("[API] ========================================")
                throw PearAPIError.unknown
            }
            
            print("[API] Attempting to decode response...")
            do {
                let decodedResponse = try self.decoder.decode(TradeExecuteResponse.self, from: data)
                print("[API] ========================================")
                print("[API] ✅ Decoding SUCCESS")
                print("[API] ========================================")
                print("[API] Decoded response:")
                print("[API]   - orderId: \(decodedResponse.orderId)")
                print("[API]   - fills count: \(decodedResponse.fills?.count ?? 0)")
                return decodedResponse
            } catch {
                print("[API] ========================================")
                print("[API] ❌ Decoding FAILED")
                print("[API] ========================================")
                print("[API] Decoding error type: \(type(of: error))")
                print("[API] Decoding error description: \(error.localizedDescription)")
                print("[API] Full decoding error: \(error)")
                throw error
            }
        }
    }
    
    func closePosition(request: ClosePositionRequest) async throws -> ClosePositionResponse {
        // Pear API uses path parameter for position ID: /positions/{positionId}/close
        let url = "\(baseURL)\(Constants.API.positions)/\(request.positionId)/close"
        
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
    
    func closeAllPositions(agentWalletAddress: String) async throws -> ClosePositionResponse {
        let url = "\(baseURL)\(Constants.API.positions)/close-all"
        
        let request = CloseAllPositionsRequest(agentWalletAddress: agentWalletAddress)
        
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
    
    func adjustPosition(positionId: String, request: AdjustPositionRequest) async throws -> PositionAdjustResponse {
        let url = "\(baseURL)\(Constants.API.positions)/\(positionId)/adjust"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(PositionAdjustResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func adjustPositionAdvanced(positionId: String, request: AdjustPositionAdvancedRequest) async throws -> PositionAdjustResponse {
        let url = "\(baseURL)\(Constants.API.positions)/\(positionId)/adjust-advance"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(PositionAdjustResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func adjustPositionLeverage(positionId: String, request: AdjustLeverageRequest) async throws -> PositionAdjustResponse {
        let url = "\(baseURL)\(Constants.API.positions)/\(positionId)/adjust-leverage"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(PositionAdjustResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func updatePositionRiskParameters(positionId: String, request: UpdateRiskParametersRequest) async throws -> PositionAdjustResponse {
        let url = "\(baseURL)\(Constants.API.positions)/\(positionId)/riskParameters"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .put,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(PositionAdjustResponse.self, decoder: self.decoder)
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
    
    // MARK: - Authentication Endpoints
    func getEIP712Message(address: String, clientId: String) async throws -> EIP712MessageResponse {
        let url = "\(baseURL)/auth/eip712-message"
        
        let parameters: [String: String] = [
            "address": address,
            "clientId": clientId
        ]
        
        return try await withRetry {
            let response = try await self.session.request(
                url,
                method: .get,
                parameters: parameters,
                headers: self.headers
            )
            .validate()
            .serializingData()
            .value
            
            // Log the raw response to see the exact structure
            if let responseString = String(data: response, encoding: .utf8) {
                print("🟡 [HYPO-D] Raw EIP-712 message response: \(responseString)")
            }
            
            // Decode and log the message structure
            let eip712Response = try self.decoder.decode(EIP712MessageResponse.self, from: response)
            
            print("🟡 [HYPO-D] Decoded EIP-712 message structure:")
            print("🟡 [HYPO-D]   Primary type: \(eip712Response.primaryType)")
            print("🟡 [HYPO-D]   Domain: name=\(eip712Response.domain.name), version=\(eip712Response.domain.version), chainId=\(eip712Response.domain.chainId)")
            print("🟡 [HYPO-D]   Message fields:")
            for (key, value) in eip712Response.message.sorted(by: { $0.key < $1.key }) {
                let valueType = type(of: value.value)
                print("🟡 [HYPO-D]     - \(key): \(value.value) (AnyCodable wrapping: \(valueType))")
            }
            
            return eip712Response
        }
    }
    
    func login(address: String, clientId: String, signature: String, timestamp: Int) async throws -> LoginResponse {
        let url = "\(baseURL)/auth/login"
        
        // CRITICAL: The timestamp parameter is already an Int, which is what the API expects
        // This timestamp MUST be the EXACT same value that was in the signed EIP-712 message
        // The API will reconstruct the message with this timestamp and verify the signature
        
        // #region agent log
        // HYPOTHESIS B was REJECTED - v-value normalization didn't help
        // Keeping original signature without modification
        print("🟡 [HYPO-B] Using ORIGINAL signature without v-value modification")
        print("🟡 [HYPO-B] Signature v-value (last 2 hex chars): \(String(signature.suffix(2)))")
        // #endregion
        
        let request = LoginRequest(address: address, clientId: clientId, signature: signature, timestamp: timestamp)
        
        // #region agent log
        let timestampDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let currentDate = Date()
        let timestampAge = currentDate.timeIntervalSince(timestampDate)
        
        print("🟡 [HYPO-LOGIN] ========================================")
        print("🟡 [HYPO-LOGIN] 📋 LOGIN REQUEST - TIMESTAMP VERIFICATION")
        print("🟡 [HYPO-LOGIN] ========================================")
        print("🟡 [HYPO-LOGIN] URL: \(url)")
        print("🟡 [HYPO-LOGIN] Address: \(address)")
        print("🟡 [HYPO-LOGIN] Client ID: \(clientId)")
        print("🟡 [HYPO-LOGIN] Signature length: \(signature.count), starts with 0x: \(signature.hasPrefix("0x"))")
        print("🟡 [HYPO-LOGIN] ⏰ TIMESTAMP BEING SENT: \(timestamp) (type: Int)")
        print("🟡 [HYPO-LOGIN] ⏰ Timestamp date: \(timestampDate)")
        print("🟡 [HYPO-LOGIN] ⏰ Timestamp age: \(timestampAge) seconds")
        print("🟡 [HYPO-LOGIN] ⏰ Current time: \(currentDate)")
        print("🟡 [HYPO-LOGIN] ⚠️  CRITICAL: This timestamp MUST match the EXACT value from the signed EIP-712 message")
        print("🟡 [HYPO-LOGIN] ⚠️  The API will reconstruct the message with this timestamp and verify the signature")
        print("🟡 [HYPO-LOGIN] ========================================")
        
        // Log the actual JSON being sent - verify timestamp is in details
        if let jsonData = try? JSONEncoder().encode(request),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🟡 [HYPO-LOGIN] Request JSON: \(jsonString)")
            
            // Parse and verify timestamp in JSON - CRITICAL VERIFICATION
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let details = jsonObject["details"] as? [String: Any],
               let jsonTimestamp = details["timestamp"] as? Int {
                print("🟡 [HYPO-LOGIN] ✅ TIMESTAMP IN JSON: \(jsonTimestamp)")
                print("🟡 [HYPO-LOGIN] ✅ Expected: \(timestamp)")
                print("🟡 [HYPO-LOGIN] ✅ Matches: \(jsonTimestamp == timestamp)")
                
                if jsonTimestamp != timestamp {
                    print("🟡 [HYPO-LOGIN] ❌❌❌ CRITICAL ERROR: Timestamp mismatch in JSON!")
                    print("🟡 [HYPO-LOGIN] ❌ Expected: \(timestamp)")
                    print("🟡 [HYPO-LOGIN] ❌ Found in JSON: \(jsonTimestamp)")
                    print("🟡 [HYPO-LOGIN] ❌ This will cause API signature verification to FAIL")
                    throw PearAPIError.invalidRequest("Timestamp mismatch in request JSON")
                } else {
                    print("🟡 [HYPO-LOGIN] ✅✅✅ Timestamp verified in JSON - matches expected value")
                }
            } else {
                print("🟡 [HYPO-LOGIN] ⚠️  Could not verify timestamp in JSON (parsing failed)")
            }
        }
        // #endregion
        
        // Make request without retry to capture response body on error
        let response = await self.session.request(
            url,
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: self.headers
        )
        .serializingData()
        .response
        
        // #region agent log
        if let data = response.data, let bodyString = String(data: data, encoding: .utf8) {
            print("🟡 [HYPO-LOGIN] Response body: \(bodyString)")
            
            // Parse error response for detailed analysis
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorMessage = errorJson["message"] as? String {
                    print("🟡 [HYPO-A,B,C,D,E] API error message: '\(errorMessage)'")
                    
                    // Analyze error message for signature-related issues
                    if errorMessage.lowercased().contains("signature") {
                        print("🟡 [HYPO-B] ⚠️ SIGNATURE-RELATED ERROR")
                        print("🟡 [HYPO-B] Possible causes:")
                        print("🟡 [HYPO-B]   1. v-value format mismatch (27/28 vs 0/1)")
                        print("🟡 [HYPO-B]   2. Message hash mismatch (different typed data structure)")
                        print("🟡 [HYPO-A]   3. Missing EIP712Domain in types")
                        print("🟡 [HYPO-D]   4. Field order mismatch in message/types")
                        print("🟡 [HYPO-E]   5. Domain field encoding issue")
                    }
                    if errorMessage.lowercased().contains("invalid") {
                        print("🟡 [HYPO-A,B,C,D,E] 'Invalid' suggests signature verification failed completely")
                        print("🟡 [HYPO-A,B,C,D,E] The server's computed hash != client's signed hash")
                    }
                }
            }
        }
        if let statusCode = response.response?.statusCode {
            print("🟡 [HYPO-LOGIN] Response status: \(statusCode)")
            
            // SUCCESS VERIFICATION: 200 means signature was correct!
            if statusCode == 200 {
                print("🟡 [HYPO-LOGIN] ✅✅✅ 200 SUCCESS ✅✅✅")
                print("🟡 [HYPO-F] ✅✅✅ JSON STRING FORMAT WORKED! ✅✅✅")
                print("🟡 [HYPO-LOGIN] ✅ Authentication successful!")
            } else if statusCode == 401 {
                print("🟡 [HYPO-LOGIN] ❌ 401 UNAUTHORIZED - Signature verification STILL failed")
                print("🟡 [HYPO-F] ❌ JSON string format did NOT fix the issue")
                print("🟡 [HYPO-LOGIN] ❌ Server could not verify the EIP-712 signature")
                print("🟡 [HYPO-LOGIN] Signature sent (last 4 chars - v value): \(String(signature.suffix(4)))")
                print("🟡 [HYPO-G] Next: Check if typed data structure differs from API response")
            }
        }
        // #endregion
        
        // Check for errors
        if let error = response.error {
            throw error
        }
        
        guard let data = response.data else {
            throw PearAPIError.unknown
        }
        
        // Check status code - if 401, handle authentication failure properly
        if let statusCode = response.response?.statusCode, statusCode == 401 {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                print("🟡 [HYPO-LOGIN] Authentication failed: \(message)")
                
                if message.lowercased().contains("timestamp") {
                    print("🟡 [HYPO-LOGIN] Timestamp validation error detected")
                    throw TimestampError(message: message)
                } else if message.lowercased().contains("signature") {
                    print("🟡 [HYPO-LOGIN] Signature verification error detected")
                    throw PearAPIError.invalidRequest("EIP-712 signature verification failed. The signed message may not match what the server expects.")
                } else {
                    throw PearAPIError.invalidRequest(message)
                }
            } else {
                throw PearAPIError.unauthorized
            }
        }
        
        do {
            // #region agent log
            print("🟡 [HYPO-LOGIN] Attempting to decode LoginResponse...")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🟡 [HYPO-LOGIN] Response JSON: \(responseString)")
            }
            // #endregion
            
            let loginResponse = try self.decoder.decode(LoginResponse.self, from: data)
            
            // #region agent log
            print("🟡 [HYPO-LOGIN] ✅ Decoding SUCCESS!")
            print("🟡 [HYPO-LOGIN] accessToken length: \(loginResponse.accessToken.count)")
            print("🟡 [HYPO-LOGIN] refreshToken length: \(loginResponse.refreshToken.count)")
            print("🟡 [HYPO-LOGIN] expiresIn: \(loginResponse.expiresIn)")
            print("🟡 [HYPO-LOGIN] tokenType: \(loginResponse.tokenType)")
            // #endregion
            
            return loginResponse
        } catch {
            print("🟡 [HYPO-LOGIN] ❌ Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("🟡 [HYPO-LOGIN] Missing key: \(key.stringValue)")
                    print("🟡 [HYPO-LOGIN] Context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("🟡 [HYPO-LOGIN] Type mismatch: expected \(type), context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("🟡 [HYPO-LOGIN] Value not found: \(type), context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("🟡 [HYPO-LOGIN] Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("🟡 [HYPO-LOGIN] Unknown decoding error")
                }
            }
            throw PearAPIError.decodingError
        }
    }
    
    func loginWithRetry(address: String, clientId: String, signature: String, timestamp: Int) async throws -> LoginResponse {
        let url = "\(baseURL)/auth/login"
        
        let request = LoginRequest(address: address, clientId: clientId, signature: signature, timestamp: timestamp)
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(LoginResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        let url = "\(baseURL)/auth/refresh"
        
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(TokenResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func logout(refreshToken: String) async throws -> LogoutResponse {
        let url = "\(baseURL)\(Constants.API.authLogout)"
        
        let request = LogoutRequest(refreshToken: refreshToken)
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(LogoutResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Health
    func checkHealth() async throws -> HealthResponse {
        let url = "\(baseURL)\(Constants.API.health)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(HealthResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Accounts
    func fetchAccount() async throws -> AccountResponse {
        let url = "\(baseURL)\(Constants.API.accounts)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(AccountResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Notifications
    func fetchNotifications(
        limit: Int = 50,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> NotificationsResponse {
        let url = "\(baseURL)\(Constants.API.notifications)"
        
        var parameters: [String: Any] = ["limit": limit]
        
        if let startDate = startDate {
            let formatter = ISO8601DateFormatter()
            parameters["startDate"] = formatter.string(from: startDate)
        }
        
        if let endDate = endDate {
            let formatter = ISO8601DateFormatter()
            parameters["endDate"] = formatter.string(from: endDate)
        }
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                parameters: parameters,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(NotificationsResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func markNotificationsRead(request: MarkNotificationsReadRequest) async throws -> MarkNotificationsReadResponse {
        let url = "\(baseURL)\(Constants.API.notifications)/read"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(MarkNotificationsReadResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Watchlist
    func toggleWatchlist(request: ToggleWatchlistRequest) async throws -> ToggleWatchlistResponse {
        let url = "\(baseURL)\(Constants.API.watchlist)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(ToggleWatchlistResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func fetchWatchlist() async throws -> WatchlistResponse {
        let url = "\(baseURL)\(Constants.API.watchlist)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(WatchlistResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Portfolio
    func fetchPortfolio() async throws -> PortfolioResponse {
        let url = "\(baseURL)\(Constants.API.portfolio)"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(PortfolioResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    // MARK: - Orders
    func fetchOpenOrders() async throws -> OpenOrdersResponse {
        let url = "\(baseURL)\(Constants.API.orders)/open"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(OpenOrdersResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func fetchTWAPOrders() async throws -> TWAPOrdersResponse {
        let url = "\(baseURL)\(Constants.API.orders)/twap"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .get,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(TWAPOrdersResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func executeSpotOrder(request: SpotOrderRequest) async throws -> SpotOrderResponse {
        let url = "\(baseURL)\(Constants.API.orders)/spot"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(SpotOrderResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func cancelOrder(orderId: String) async throws -> CancelOrderResponse {
        let url = "\(baseURL)\(Constants.API.orders)/\(orderId)/cancel"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .delete,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(CancelOrderResponse.self, decoder: self.decoder)
            .value
        }
    }
    
    func cancelTWAPOrder(orderId: String) async throws -> CancelOrderResponse {
        let url = "\(baseURL)\(Constants.API.orders)/\(orderId)/twap/cancel"
        
        return try await withRetry {
            try await self.session.request(
                url,
                method: .post,
                headers: self.headers
            )
            .validate()
            .serializingDecodable(CancelOrderResponse.self, decoder: self.decoder)
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
        print("[API] ========================================")
        print("[API] withRetry() - ENTRY")
        print("[API] ========================================")
        print("[API] maxAttempts: \(maxAttempts)")
        
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            print("[API] ========================================")
            print("[API] Retry attempt \(attempt + 1)/\(maxAttempts)")
            print("[API] ========================================")
            
            do {
                print("[API] Calling operation()...")
                let startTime = Date()
                let result = try await operation()
                let duration = Date().timeIntervalSince(startTime)
                print("[API] Operation completed successfully in \(duration)s")
                print("[API] ========================================")
                print("[API] withRetry() - SUCCESS EXIT")
                print("[API] ========================================")
                return result
            } catch {
                lastError = error
                print("[API] Operation failed with error")
                print("🔵 [DEBUG] API retry attempt \(attempt + 1)/\(maxAttempts) failed: \(error)")
                
                // Check for various error types
                if let afError = error as? AFError {
                    switch afError {
                    case .responseValidationFailed(let reason):
                        if case .unacceptableStatusCode(let code) = reason {
                            print("🔵 [DEBUG] HTTP status code: \(code)")
                            // #region agent log
                            print("🟡 [HYPO-C] HTTP \(code) error - this means endpoint may not exist or path is wrong")
                            // #endregion
                            if code == 404 {
                                print("[API] Throwing notFound error - no more retries")
                                throw PearAPIError.notFound
                            } else if (400..<500).contains(code) {
                                print("[API] Throwing client error (\(code)) - no more retries")
                                throw PearAPIError.from(statusCode: code, message: nil)
                            } else if (500..<600).contains(code) {
                                print("[API] Throwing server error - may retry")
                            }
                        }
                    case .sessionTaskFailed(let urlError as URLError):
                        print("🔵 [DEBUG] URL error: \(urlError.code) - \(urlError.localizedDescription)")
                        if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                            print("[API] Throwing networkError - may retry")
                            throw PearAPIError.networkError
                        }
                    case .responseSerializationFailed:
                        print("🔵 [DEBUG] Response serialization failed - likely invalid JSON or schema mismatch")
                        print("[API] Throwing decodingError - no more retries")
                        throw PearAPIError.decodingError
                    default:
                        print("🔵 [DEBUG] Other AFError: \(afError)")
                    }
                }
                
                // Exponential backoff
                if attempt < maxAttempts - 1 {
                    let delay = Constants.API.retryBaseDelay * pow(2.0, Double(attempt))
                    print("[API] Waiting \(delay)s before retry \(attempt + 2)...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    print("[API] Retry delay completed")
                } else {
                    print("[API] No more retries remaining")
                }
            }
        }
        
        // Map the last error to a more specific PearAPIError if possible
        if let lastError = lastError {
            print("[API] ========================================")
            print("[API] All retries exhausted")
            print("[API] ========================================")
            print("🔵 [DEBUG] Final error after all retries: \(lastError)")
            if let urlError = (lastError as? AFError)?.underlyingError as? URLError {
                print("🔵 [DEBUG] Underlying URLError: \(urlError.code)")
                print("[API] Throwing networkError")
                throw PearAPIError.networkError
            }
        }
        
        print("[API] ========================================")
        print("[API] withRetry() - FAILURE EXIT")
        print("[API] ========================================")
        throw lastError ?? PearAPIError.unknown
    }
}

// MARK: - Timestamp Error
struct TimestampError: Error, LocalizedError {
    let message: String
    
    static let invalidTimestamp = TimestampError(message: "Invalid timestamp")
    
    var errorDescription: String? {
        return message
    }
}

// MARK: - API Errors
enum PearAPIError: Error, LocalizedError {
    case unauthorized
    case invalidRequest(String?)
    case notFound
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
        case .notFound:
            return "API endpoint not found. The server may have changed the endpoint path, or authentication may be required."
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
