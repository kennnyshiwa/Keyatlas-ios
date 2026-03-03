import Foundation

/// Manages authentication state and operations
@Observable
final class AuthService: @unchecked Sendable {
    static let shared = AuthService()

    var currentUser: UserSummary?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false

    private let api = APIClient.shared

    private init() {}

    /// Check for existing session on app launch
    func restoreSession() async {
        guard KeychainService.load(.authToken) != nil || KeychainService.load(.sessionCookie) != nil else {
            return
        }
        do {
            let session: AuthSession = try await api.request(path: "/api/auth/session", authenticated: true)
            await MainActor.run {
                self.currentUser = session.user
            }
        } catch {
            // Session expired or invalid — clear stored credentials
            KeychainService.clearAll()
        }
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        // NextAuth uses CSRF token flow — get CSRF first
        struct CSRFResponse: Codable, Sendable {
            let csrfToken: String
        }

        let csrf: CSRFResponse = try await api.request(path: "/api/auth/csrf")

        struct SignInBody: Codable, Sendable {
            let email: String
            let password: String
            let csrfToken: String
            let redirect: Bool
            let json: Bool
        }

        let body = SignInBody(
            email: email,
            password: password,
            csrfToken: csrf.csrfToken,
            redirect: false,
            json: true
        )

        struct SignInResponse: Codable, Sendable {
            let url: String?
            let ok: Bool?
            let error: String?
        }

        let response: SignInResponse = try await api.request(
            .post,
            path: "/api/auth/callback/credentials",
            body: body
        )

        if let error = response.error {
            throw APIError.validation(error)
        }

        // Fetch session after successful sign in
        await restoreSession()

        if currentUser == nil {
            throw APIError.validation("Sign in failed. Please check your credentials.")
        }
    }

    /// Register a new account
    func signUp(email: String, password: String, username: String) async throws {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let body = AuthCredentials(email: email, password: password, username: username)

        struct SignUpResponse: Codable, Sendable {
            let message: String?
            let user: UserSummary?
        }

        let response: SignUpResponse = try await api.request(.post, path: "/api/auth/signup", body: body)

        if response.user == nil {
            // Might need email verification
            return
        }

        // Auto sign-in after registration
        try await signIn(email: email, password: password)
    }

    /// Sign out and clear stored credentials
    func signOut() async {
        // Try to call server sign-out
        try? await api.requestVoid(.post, path: "/api/auth/signout", authenticated: true)
        KeychainService.clearAll()
        await MainActor.run {
            self.currentUser = nil
        }
    }
}
