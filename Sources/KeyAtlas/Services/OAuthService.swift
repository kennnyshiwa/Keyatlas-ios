import AuthenticationServices
import Foundation

/// Handles OAuth sign-in via ASWebAuthenticationSession (Discord/Google)
/// and native Sign in with Apple (ASAuthorizationAppleIDProvider).
@Observable
final class OAuthService: NSObject, @unchecked Sendable, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthService()

    var isAuthenticating = false
    var error: String?

    private static let baseURL = "https://keyatlas.io"
    private static let callbackScheme = "keyatlas"

    // Shared API client
    private let api = APIClient.shared

    // MARK: - Public sign-in methods

    /// Sign in with Discord (web OAuth via ASWebAuthenticationSession)
    func signInWithDiscord() async throws -> OAuthResult {
        try await authenticate(provider: "discord")
    }

    /// Sign in with Google (web OAuth via ASWebAuthenticationSession)
    func signInWithGoogle() async throws -> OAuthResult {
        try await authenticate(provider: "google")
    }

    /// Exchange an Apple identity token with the KeyAtlas backend.
    /// Call this from the SignInWithAppleButton onCompletion handler after
    /// extracting the token from ASAuthorizationAppleIDCredential.
    func exchangeAppleIdentityToken(
        identityToken: String,
        givenName: String?,
        familyName: String?
    ) async throws -> OAuthResult {
        await MainActor.run {
            self.isAuthenticating = true
            self.error = nil
        }
        defer { Task { @MainActor in self.isAuthenticating = false } }

        return try await appleBackendExchange(
            api: api,
            identityToken: identityToken,
            givenName: givenName,
            familyName: familyName
        )
    }

    // MARK: - Private web OAuth helper

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

// MARK: - Shared Apple backend exchange

/// Sends the Apple identity token to /api/auth/mobile/apple and returns an OAuthResult.
/// Shared between OAuthService and AppleSignInCoordinator.
func appleBackendExchange(
    api: APIClient,
    identityToken: String,
    givenName: String?,
    familyName: String?
) async throws -> OAuthResult {
    struct AppleFullName: Encodable {
        let givenName: String?
        let familyName: String?
    }

    struct AppleRequestBody: Encodable {
        let identityToken: String
        let fullName: AppleFullName?
    }

    struct AppleResponseBody: Codable {
        let token: String
        let user_id: String
        let username: String
        let role: String
        let avatar: String?
        let error: String?
    }

    let fullName: AppleFullName? =
        (givenName != nil || familyName != nil)
        ? AppleFullName(givenName: givenName, familyName: familyName)
        : nil

    let body = AppleRequestBody(identityToken: identityToken, fullName: fullName)

    let response: AppleResponseBody = try await api.request(
        .post,
        path: "/api/auth/mobile/apple",
        body: body
    )

    if let errorMsg = response.error {
        throw OAuthError.serverError(errorMsg)
    }

    return OAuthResult(
        token: response.token,
        userId: response.user_id,
        username: response.username,
        role: response.role,
        avatar: response.avatar
    )
}

// MARK: - Types

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
    case appleCredentialInvalid
    case appleCancelled

    var errorDescription: String? {
        switch self {
        case .noCallback: "No response from authentication"
        case .noToken: "No token received"
        case .serverError(let msg): msg
        case .sessionFailed: "Could not start authentication"
        case .appleCredentialInvalid: "Could not read Apple credential"
        case .appleCancelled: "Sign in was cancelled"
        }
    }
}
