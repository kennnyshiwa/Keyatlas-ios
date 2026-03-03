import AuthenticationServices
import Foundation

/// Handles OAuth sign-in via ASWebAuthenticationSession
@Observable
final class OAuthService: NSObject, @unchecked Sendable, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthService()

    var isAuthenticating = false
    var error: String?

    private static let baseURL = "https://keyatlas.io"
    private static let callbackScheme = "keyatlas"

    /// Sign in with Discord
    func signInWithDiscord() async throws -> OAuthResult {
        try await authenticate(provider: "discord")
    }

    /// Sign in with Google
    func signInWithGoogle() async throws -> OAuthResult {
        try await authenticate(provider: "google")
    }

    private func authenticate(provider: String) async throws -> OAuthResult {
        await MainActor.run {
            self.isAuthenticating = true
            self.error = nil
        }
        defer { Task { @MainActor in self.isAuthenticating = false } }

        let url = URL(string: "\(Self.baseURL)/api/auth/mobile/\(provider)")!

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    continuation.resume(throwing: OAuthError.noCallback)
                    return
                }

                let params = Dictionary(
                    uniqueKeysWithValues: (components.queryItems ?? []).compactMap {
                        guard let value = $0.value else { return nil as (String, String)? }
                        return ($0.name, value)
                    }
                )

                if let errorMsg = params["error"] {
                    continuation.resume(throwing: OAuthError.serverError(errorMsg))
                    return
                }

                guard let token = params["token"] else {
                    continuation.resume(throwing: OAuthError.noToken)
                    return
                }

                let result = OAuthResult(
                    token: token,
                    userId: params["user_id"] ?? "",
                    username: params["username"] ?? "",
                    role: params["role"] ?? "USER",
                    avatar: params["avatar"]
                )
                continuation.resume(returning: result)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: OAuthError.sessionFailed)
            }
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

struct OAuthResult: Sendable {
    let token: String
    let userId: String
    let username: String
    let role: String
    let avatar: String?
}

enum OAuthError: Error, LocalizedError {
    case noCallback
    case noToken
    case serverError(String)
    case sessionFailed

    var errorDescription: String? {
        switch self {
        case .noCallback: "No response from authentication"
        case .noToken: "No token received"
        case .serverError(let msg): msg
        case .sessionFailed: "Could not start authentication"
        }
    }
}
