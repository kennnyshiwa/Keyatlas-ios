import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var showSignUp = false
    @State private var isOAuthLoading = false

    private let oauthService = OAuthService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Logo / Title
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        Text("KeyAtlas")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Mechanical Keyboard Community Hub")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // OAuth buttons
                    VStack(spacing: 12) {
                        Button {
                            Task { await signInWithDiscord() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "message.fill")
                                    .font(.body)
                                Text("Continue with Discord")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.34, green: 0.40, blue: 0.95)) // Discord blurple
                        .disabled(isOAuthLoading || authService.isLoading)

                        Button {
                            Task { await signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.body)
                                Text("Continue with Google")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isOAuthLoading || authService.isLoading)
                    }
                    .padding(.horizontal, 32)

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                    }
                    .padding(.horizontal, 32)

                    // Email/Password form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Email address")

                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Password")

                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task { await signIn() }
                        } label: {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                }
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(email.isEmpty || password.isEmpty || authService.isLoading || isOAuthLoading)
                        .accessibilityLabel("Sign in")
                    }
                    .padding(.horizontal, 32)

                    Button("Don't have an account? Sign Up") {
                        showSignUp = true
                    }
                    .font(.subheadline)

                    Spacer(minLength: 40)
                }
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }

    private func signIn() async {
        error = nil
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func signInWithDiscord() async {
        error = nil
        isOAuthLoading = true
        defer { isOAuthLoading = false }
        do {
            let result = try await oauthService.signInWithDiscord()
            try await authService.signInWithOAuth(result: result)
        } catch {
            // User cancelled is not an error
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                return
            }
            self.error = error.localizedDescription
        }
    }

    private func signInWithGoogle() async {
        error = nil
        isOAuthLoading = true
        defer { isOAuthLoading = false }
        do {
            let result = try await oauthService.signInWithGoogle()
            try await authService.signInWithOAuth(result: result)
        } catch {
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                return
            }
            self.error = error.localizedDescription
        }
    }
}
