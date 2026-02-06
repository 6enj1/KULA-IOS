//
//  AuthService.swift
//  KULA
//
//  Authentication API Service
//

import Foundation

class AuthService {
    static let shared = AuthService()
    private let client = APIClient.shared

    private init() {}

    // MARK: - Login
    func login(email: String, password: String) async throws -> User {
        let body = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await client.post(
            path: "/auth/login",
            body: body,
            authenticated: false
        )

        // Save tokens
        TokenManager.shared.saveTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )

        return response.user.toUser()
    }

    // MARK: - Register
    func register(email: String, password: String, name: String) async throws -> User {
        let body = RegisterRequest(email: email, password: password, name: name, role: "consumer")
        let response: AuthResponse = try await client.post(
            path: "/auth/register",
            body: body,
            authenticated: false
        )

        // Save tokens
        TokenManager.shared.saveTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )

        return response.user.toUser()
    }

    // MARK: - Social Auth
    func socialAuth(provider: String, token: String, email: String?, name: String?) async throws -> User {
        let body = SocialAuthRequest(provider: provider, token: token, email: email, name: name)
        let response: AuthResponse = try await client.post(
            path: "/auth/social",
            body: body,
            authenticated: false
        )

        // Save tokens
        TokenManager.shared.saveTokens(
            access: response.accessToken,
            refresh: response.refreshToken
        )

        return response.user.toUser()
    }

    // MARK: - Get Current User
    func getCurrentUser() async throws -> User {
        let response: APIUser = try await client.get(path: "/users/me")
        return response.toUser()
    }

    // MARK: - Update Location
    func updateLocation(latitude: Double, longitude: Double) async throws {
        let body = UpdateLocationRequest(latitude: latitude, longitude: longitude)
        let _: APIUser = try await client.patch(path: "/users/me/location", body: body)
    }

    // MARK: - Update Preferences
    func updatePreferences(_ preferences: [String]) async throws {
        let body = UpdatePreferencesRequest(preferences: preferences)
        let _: APIUser = try await client.patch(path: "/users/me/preferences", body: body)
    }

    // MARK: - Update Notifications
    func updateNotifications(enabled: Bool) async throws {
        struct NotificationsRequest: Encodable {
            let enabled: Bool
        }
        let body = NotificationsRequest(enabled: enabled)
        let _: APIUser = try await client.patch(path: "/users/me/notifications", body: body)
    }

    // MARK: - Logout
    func logout() async {
        do {
            let _: MessageResponse = try await client.post(path: "/auth/logout")
        } catch {
            #if DEBUG
            print("[Auth] Logout error: \(error)")
            #endif
        }
        TokenManager.shared.clearTokens()
    }

    // MARK: - Check Auth Status
    var isLoggedIn: Bool {
        TokenManager.shared.isLoggedIn
    }
}
