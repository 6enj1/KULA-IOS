//
//  APIClient.swift
//  KULA
//
//  Base API Client for network requests
//

import Foundation
#if !DEBUG
import CommonCrypto
#endif

// MARK: - API Configuration
enum APIConfig {
    // IMPORTANT: Set KULA_API_URL in build settings or Info.plist for production
    #if DEBUG
    static let baseURL = "http://192.168.1.114:3000/api/v1"
    #else
    static var baseURL: String {
        // Read from Info.plist or environment
        if let url = Bundle.main.object(forInfoDictionaryKey: "KULA_API_URL") as? String,
           !url.isEmpty,
           url != "$(KULA_API_URL)" {
            return url
        }
        // Fail loudly in production if not configured
        fatalError("FATAL: KULA_API_URL not configured in Info.plist. Cannot start app without API endpoint.")
    }
    #endif

    static let timeout: TimeInterval = 30
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Please log in again"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Response Wrapper
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

// MARK: - Auth Response
struct AuthResponse: Decodable {
    let user: APIUser
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

// MARK: - Checkout Response
struct CheckoutInfo: Decodable {
    let id: String
    let paymentUrl: String
}

struct OrderWithCheckout: Decodable {
    let order: APIOrder
    let checkout: CheckoutInfo
}

// MARK: - Pagination
struct PaginatedResponse<T: Decodable>: Decodable {
    let data: [T]
    let pagination: Pagination
}

struct Pagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasMore: Bool
}

// MARK: - Token Storage (Secure Keychain wrapper)
class TokenManager {
    static let shared = TokenManager()

    private let keychain = KeychainManager.shared

    private init() {
        // Migrate tokens from UserDefaults to Keychain on first access
        keychain.migrateFromUserDefaults()
    }

    var accessToken: String? {
        get { keychain.accessToken }
        set { keychain.accessToken = newValue }
    }

    var refreshToken: String? {
        get { keychain.refreshToken }
        set { keychain.refreshToken = newValue }
    }

    var isLoggedIn: Bool {
        keychain.isLoggedIn
    }

    func saveTokens(access: String, refresh: String) {
        keychain.saveTokens(access: access, refresh: refresh)
    }

    func clearTokens() {
        keychain.clearTokens()
    }
}

// MARK: - Certificate Pinning Delegate
#if !DEBUG
final class SSLPinningDelegate: NSObject, URLSessionDelegate {
    // SHA-256 hash of your server's certificate public key (base64 encoded)
    // IMPORTANT: Replace with your actual certificate pin before production release
    // Generate with: openssl x509 -in cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
    private let pinnedPublicKeyHashes: [String] = [
        // Add your certificate pin here, e.g.:
        // "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    ]

    func urlSession(_ session: URLSession,
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Skip pinning if no pins configured (allows initial setup)
        if pinnedPublicKeyHashes.isEmpty {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Get server certificate
        guard let serverCertificate = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let certificate = serverCertificate.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get public key data
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Hash the public key
        let hash = publicKeyData.sha256().base64EncodedString()

        // Check if the hash matches any of our pinned hashes
        if pinnedPublicKeyHashes.contains(hash) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}
#endif

// MARK: - Refresh Token Response
struct RefreshTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

// MARK: - API Client
class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    #if !DEBUG
    private let pinningDelegate = SSLPinningDelegate()
    #endif

    // Token refresh state to prevent concurrent refresh attempts
    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<Void, Error>] = []

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout

        #if DEBUG
        // No pinning in debug mode for local development
        self.session = URLSession(configuration: config)
        #else
        // Enable certificate pinning in production
        self.session = URLSession(configuration: config, delegate: pinningDelegate, delegateQueue: nil)
        #endif

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
    }

    // MARK: - Request Building
    private func buildURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        var components = URLComponents(string: "\(APIConfig.baseURL)\(path)")
        components?.queryItems = queryItems
        return components?.url
    }

    private func buildRequest(url: URL, method: String, body: Data? = nil, authenticated: Bool = true) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = TokenManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    // MARK: - Token Refresh
    private func refreshAccessToken() async throws {
        // If already refreshing, wait for the result
        if isRefreshing {
            try await withCheckedThrowingContinuation { continuation in
                refreshContinuations.append(continuation)
            }
            return
        }

        guard let refreshToken = TokenManager.shared.refreshToken else {
            throw APIError.unauthorized
        }

        isRefreshing = true
        #if DEBUG
        print("[APIClient] Refreshing access token...")
        #endif

        defer {
            isRefreshing = false
            // Resume all waiting continuations
            let continuations = refreshContinuations
            refreshContinuations.removeAll()
            for continuation in continuations {
                continuation.resume()
            }
        }

        guard let url = buildURL(path: "/auth/refresh") else {
            throw APIError.invalidURL
        }

        struct RefreshRequest: Encodable {
            let refreshToken: String
        }

        let bodyData = try JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                let apiResponse = try decoder.decode(APIResponse<RefreshTokenResponse>.self, from: data)
                if apiResponse.success, let tokenData = apiResponse.data {
                    TokenManager.shared.saveTokens(
                        access: tokenData.accessToken,
                        refresh: tokenData.refreshToken
                    )
                    #if DEBUG
                    print("[APIClient] Token refresh successful")
                    #endif
                    return
                }
            }

            // Refresh failed - clear tokens
            #if DEBUG
            print("[APIClient] Token refresh failed with status: \(httpResponse.statusCode)")
            #endif
            TokenManager.shared.clearTokens()
            throw APIError.unauthorized
        } catch let error as APIError {
            TokenManager.shared.clearTokens()
            throw error
        } catch {
            TokenManager.shared.clearTokens()
            throw APIError.unauthorized
        }
    }

    // MARK: - Generic Request
    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        authenticated: Bool = true,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        guard let url = buildURL(path: path, queryItems: queryItems) else {
            throw APIError.invalidURL
        }

        var bodyData: Data? = nil
        if let body = body {
            bodyData = try JSONEncoder().encode(body)
        }

        let request = buildRequest(url: url, method: method, body: bodyData, authenticated: authenticated)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            // Debug: Print response
            #if DEBUG
            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response [\(path)]: \(jsonString.prefix(500))")
            }
            #endif

            // Handle HTTP errors
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                // Try to refresh the token if this is the first attempt
                if authenticated && retryOnUnauthorized && TokenManager.shared.refreshToken != nil {
                    #if DEBUG
                    print("[APIClient] Got 401, attempting token refresh...")
                    #endif
                    try await refreshAccessToken()
                    // Retry the request with new token (don't retry again if this fails)
                    return try await self.request(
                        path: path,
                        method: method,
                        body: body,
                        queryItems: queryItems,
                        authenticated: authenticated,
                        retryOnUnauthorized: false
                    )
                }
                TokenManager.shared.clearTokens()
                throw APIError.unauthorized
            default:
                if let errorResponse = try? decoder.decode(APIResponse<String>.self, from: data) {
                    throw APIError.serverError(errorResponse.error ?? "Unknown error")
                }
                throw APIError.serverError("Server error: \(httpResponse.statusCode)")
            }

            // Decode response
            do {
                let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
                if apiResponse.success, let data = apiResponse.data {
                    return data
                } else if let error = apiResponse.error {
                    throw APIError.serverError(error)
                } else {
                    throw APIError.noData
                }
            } catch let decodingError as DecodingError {
                #if DEBUG
                print("Decoding error: \(decodingError)")
                #endif
                throw APIError.decodingError(decodingError)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Convenience Methods
    func get<T: Decodable>(path: String, queryItems: [URLQueryItem]? = nil, authenticated: Bool = true) async throws -> T {
        try await request(path: path, method: "GET", queryItems: queryItems, authenticated: authenticated)
    }

    func post<T: Decodable>(path: String, body: Encodable? = nil, authenticated: Bool = true) async throws -> T {
        try await request(path: path, method: "POST", body: body, authenticated: authenticated)
    }

    func patch<T: Decodable>(path: String, body: Encodable? = nil) async throws -> T {
        try await request(path: path, method: "PATCH", body: body)
    }

    func delete<T: Decodable>(path: String) async throws -> T {
        try await request(path: path, method: "DELETE")
    }
}
