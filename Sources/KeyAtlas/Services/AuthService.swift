import Foundation

/// Manages authentication state and operations
@Observable
final class AuthService: @unchecked Sendable {
    static let shared = AuthService()

    var currentUser: UserSummary?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false

    @MainActor private var sessionGeneration = 0
    @MainActor private var isSigningOut = false

    @MainActor private func beginSessionTransition(signingOut: Bool = false) -> Int {
        sessionGeneration += 1
        SessionLifetime.shared.invalidate()
        currentUser = nil
        isSigningOut = signingOut
        return sessionGeneration
    }
    private let api: APIClient

    init(api: APIClient = .shared) { self.api = api }

    /// Check for existing session on app launch
    func restoreSession() async {
        guard let generation = await MainActor.run(body: { self.isSigningOut ? nil : self.sessionGeneration }) else { return }
        guard KeychainService.load(.authToken) != nil || KeychainService.load(.sessionCookie) != nil else {
            return
        }
        do {
            // Try API key auth first (mobile OAuth flow)
            let response: APIDataResponse<UserProfile> = try await api.request(path: "/api/v1/profile", authenticated: true)
            let profile = response.data
            await MainActor.run {
                guard self.sessionGeneration == generation else { return }
                self.currentUser = UserSummary(
                    id: profile.id,
                    username: profile.username,
                    name: profile.name,
                    avatarUrl: profile.image,
                    image: profile.image,
                    role: profile.role
                )
            }
            await PushNotificationService.shared.syncTokenIfPossible()
        } catch {
            // A superseded restore must not start fallback with a newer credential.
            guard await MainActor.run(body: { self.sessionGeneration == generation && !self.isSigningOut }) else { return }
            // Try NextAuth session as fallback
            do {
                let session: AuthSession = try await api.request(path: "/api/auth/session", authenticated: true)
                await MainActor.run {
                    guard self.sessionGeneration == generation else { return }
                    self.currentUser = session.user
                }
            } catch {
                // Session expired or invalid — clear stored credentials
                await MainActor.run {
                    guard self.sessionGeneration == generation else { return }
                    _ = self.beginSessionTransition()
                    KeychainService.clearAll()
                }
            }
        }
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        let generation = await MainActor.run {
            self.isLoading = true
            let generation = self.beginSessionTransition()
            KeychainService.clearAll()
            return generation
        }
        defer { Task { @MainActor in self.isLoading = false } }

        // Use the mobile login API endpoint (returns JSON with API key)
        struct LoginBody: Codable, Hashable, Sendable {
            let email: String
            let password: String
        }

        struct LoginUser: Codable, Hashable, Sendable {
            let id: String
            let username: String?
            let email: String
            let role: String
            let avatar: String?
        }

        struct LoginData: Codable, Hashable, Sendable {
            let apiKey: String
            let user: LoginUser
        }

        struct LoginResponse: Codable, Hashable, Sendable {
            let data: LoginData?
            let error: String?
        }

        let body = LoginBody(email: email, password: password)

        let response: LoginResponse = try await api.request(
            .post,
            path: "/api/v1/auth/login",
            body: body
        )

        if let error = response.error {
            throw APIError.validation(error)
        }

        guard let loginData = response.data else {
            throw APIError.validation("Sign in failed. Please check your credentials.")
        }

        try await MainActor.run {
            guard self.sessionGeneration == generation else { throw APIError.unauthorized }
            try KeychainService.save(loginData.apiKey, for: .authToken)
        }

        // Restore session using the new API key
        await restoreSession()

        if currentUser == nil {
            throw APIError.validation("Sign in succeeded but session could not be restored.")
        }
    }

    /// Register a new account
    func signUp(email: String, password: String, username: String) async throws {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let body = AuthCredentials(email: email, password: password, username: username)

        struct SignUpResponse: Codable, Hashable, Sendable {
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

    /// Sign in with OAuth (Discord or Google)
    func signInWithOAuth(result: OAuthResult) async throws {
        let generation = try await MainActor.run {
            let generation = self.beginSessionTransition()
            KeychainService.clearAll()
            try KeychainService.save(result.token, for: .authToken)
            return generation
        }

        // Resolve authenticated profile immediately via API-key auth
        do {
            let response: APIDataResponse<UserProfile> = try await api.request(path: "/api/v1/profile", authenticated: true)
            let profile = response.data
            await MainActor.run {
                guard self.sessionGeneration == generation else { return }
                self.currentUser = UserSummary(
                    id: profile.id,
                    username: profile.username,
                    name: profile.name,
                    avatarUrl: profile.image,
                    image: profile.image,
                    role: profile.role
                )
            }
            await PushNotificationService.shared.syncTokenIfPossible()
        } catch {
            // Keep token but surface error so UI can retry/sign out
            throw error
        }
    }

    /// Sign out and clear stored credentials
    func signOut() async {
        // Hide account-specific cards immediately, before network cleanup.
        let (generation, sessionID) = await MainActor.run {
            let generation = self.beginSessionTransition(signingOut: true)
            return (generation, SessionLifetime.shared.id)
        }
        await PushNotificationService.shared.unregisterCurrentToken()
        // Try to call server sign-out
        try? await api.requestVoid(.post, path: "/api/auth/signout", authenticated: true, expectedSessionID: sessionID)
        await MainActor.run {
            guard self.sessionGeneration == generation else { return }
            KeychainService.clearAll()
            self.isSigningOut = false
            self.currentUser = nil
        }
    }
}
