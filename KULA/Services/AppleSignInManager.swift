//
//  AppleSignInManager.swift
//  KULA
//
//  Handles Apple Sign In authentication flow
//

import Foundation
import AuthenticationServices

/// Result from Apple Sign In containing the identity token and user info
struct AppleSignInResult {
    let identityToken: String
    let email: String?
    let fullName: PersonNameComponents?

    /// Formatted full name string
    var displayName: String? {
        guard let fullName = fullName else { return nil }
        var components: [String] = []
        if let givenName = fullName.givenName {
            components.append(givenName)
        }
        if let familyName = fullName.familyName {
            components.append(familyName)
        }
        return components.isEmpty ? nil : components.joined(separator: " ")
    }
}

/// Error types for Apple Sign In
enum AppleSignInError: LocalizedError {
    case cancelled
    case failed(Error)
    case invalidCredential
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled"
        case .failed(let error):
            return "Sign in failed: \(error.localizedDescription)"
        case .invalidCredential:
            return "Invalid credential received"
        case .missingIdentityToken:
            return "Missing identity token from Apple"
        }
    }
}

/// Manager class that handles Apple Sign In flow
@MainActor
final class AppleSignInManager: NSObject {
    static let shared = AppleSignInManager()

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    private override init() {
        super.init()
    }

    /// Initiates Apple Sign In flow and returns the result
    func signIn() async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// Checks the credential state for a given user ID
    func checkCredentialState(userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                continuation?.resume(throwing: AppleSignInError.invalidCredential)
                continuation = nil
                return
            }

            guard let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
                continuation = nil
                return
            }

            // Note: email and fullName are only provided on first sign in
            // For returning users, these will be nil
            let result = AppleSignInResult(
                identityToken: identityToken,
                email: credential.email,
                fullName: credential.fullName
            )

            continuation?.resume(returning: result)
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    continuation?.resume(throwing: AppleSignInError.cancelled)
                default:
                    continuation?.resume(throwing: AppleSignInError.failed(error))
                }
            } else {
                continuation?.resume(throwing: AppleSignInError.failed(error))
            }
            continuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the first window from the first connected scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
