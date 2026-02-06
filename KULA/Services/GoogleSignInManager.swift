//
//  GoogleSignInManager.swift
//  KULA
//
//  Handles Google Sign In authentication flow
//
//  SETUP REQUIRED:
//  1. Add GoogleSignIn-iOS package via Xcode: File > Add Package Dependencies
//     URL: https://github.com/google/GoogleSignIn-iOS (version 7.x)
//  2. Add your Google Client ID to Info.plist as GIDClientID
//  3. Add the reversed client ID as a URL scheme in Info.plist
//

import Foundation
import UIKit
import GoogleSignIn

/// Result from Google Sign In containing the ID token and user info
struct GoogleSignInResult {
    let idToken: String
    let email: String?
    let name: String?
}

/// Error types for Google Sign In
enum GoogleSignInError: LocalizedError {
    case cancelled
    case failed(Error)
    case missingClientID
    case missingIDToken
    case noRootViewController

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled"
        case .failed(let error):
            return "Sign in failed: \(error.localizedDescription)"
        case .missingClientID:
            return "Google Client ID not configured in Info.plist"
        case .missingIDToken:
            return "Missing ID token from Google"
        case .noRootViewController:
            return "Unable to present sign in"
        }
    }
}

/// Manager class that handles Google Sign In flow
@MainActor
final class GoogleSignInManager {
    static let shared = GoogleSignInManager()

    private init() {}

    /// Initiates Google Sign In flow and returns the result
    func signIn() async throws -> GoogleSignInResult {
        // Get client ID from Info.plist
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            throw GoogleSignInError.missingClientID
        }

        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the root view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw GoogleSignInError.noRootViewController
        }

        // Find the topmost presented view controller
        var presentingVC = rootViewController
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)

            guard let idToken = result.user.idToken?.tokenString else {
                throw GoogleSignInError.missingIDToken
            }

            return GoogleSignInResult(
                idToken: idToken,
                email: result.user.profile?.email,
                name: result.user.profile?.name
            )
        } catch let error as GIDSignInError {
            if error.code == .canceled {
                throw GoogleSignInError.cancelled
            }
            throw GoogleSignInError.failed(error)
        } catch {
            throw GoogleSignInError.failed(error)
        }
    }

    /// Handles the URL callback from Google Sign In
    /// Call this from your App's onOpenURL handler
    func handle(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    /// Signs out the current Google user
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    /// Restores a previous sign-in session if available
    func restorePreviousSignIn() async -> GoogleSignInResult? {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            guard let idToken = user.idToken?.tokenString else { return nil }
            return GoogleSignInResult(
                idToken: idToken,
                email: user.profile?.email,
                name: user.profile?.name
            )
        } catch {
            return nil
        }
    }
}
