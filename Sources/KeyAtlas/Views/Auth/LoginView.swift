import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

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

                // Form
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
                    .disabled(email.isEmpty || password.isEmpty || authService.isLoading)
                    .accessibilityLabel("Sign in")
                }
                .padding(.horizontal, 32)

                Button("Don't have an account? Sign Up") {
                    showSignUp = true
                }
                .font(.subheadline)

                Spacer()
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
}
