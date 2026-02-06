//
//  KeychainManager.swift
//  KULA
//
//  Secure token storage using iOS Keychain
//

import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.savr.app"
    private let accessTokenKey = "savr_access_token"
    private let refreshTokenKey = "savr_refresh_token"

    private init() {}

    // MARK: - Public Interface

    var accessToken: String? {
        get { retrieve(key: accessTokenKey) }
        set {
            if let value = newValue {
                save(key: accessTokenKey, value: value)
            } else {
                delete(key: accessTokenKey)
            }
        }
    }

    var refreshToken: String? {
        get { retrieve(key: refreshTokenKey) }
        set {
            if let value = newValue {
                save(key: refreshTokenKey, value: value)
            } else {
                delete(key: refreshTokenKey)
            }
        }
    }

    var isLoggedIn: Bool {
        accessToken != nil
    }

    func saveTokens(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
    }

    func clearTokens() {
        accessToken = nil
        refreshToken = nil
    }

    // MARK: - Private Keychain Operations

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        #if DEBUG
        if status != errSecSuccess {
            print("[Keychain] Save failed for key \(key): \(status)")
        }
        #endif
    }

    private func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Migration from UserDefaults

    /// Call this once on app startup to migrate tokens from UserDefaults to Keychain
    func migrateFromUserDefaults() {
        let oldAccessKey = "kula_access_token"
        let oldRefreshKey = "kula_refresh_token"

        // Check if we have old tokens in UserDefaults
        if let oldAccess = UserDefaults.standard.string(forKey: oldAccessKey),
           accessToken == nil {
            accessToken = oldAccess
            UserDefaults.standard.removeObject(forKey: oldAccessKey)
            #if DEBUG
            print("[Keychain] Migrated access token from UserDefaults")
            #endif
        }

        if let oldRefresh = UserDefaults.standard.string(forKey: oldRefreshKey),
           refreshToken == nil {
            refreshToken = oldRefresh
            UserDefaults.standard.removeObject(forKey: oldRefreshKey)
            #if DEBUG
            print("[Keychain] Migrated refresh token from UserDefaults")
            #endif
        }
    }
}
