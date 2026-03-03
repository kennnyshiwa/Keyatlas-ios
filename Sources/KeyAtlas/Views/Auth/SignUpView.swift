import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var error: String?
    @State private var showVerificationMessage = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Username")

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Email address")

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .accessibilityLabel("Password")

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .accessibilityLabel("Confirm password")
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if showVerificationMessage {
                    Section {
                        Label("Check your email to verify your account!", systemImage: "envelope.badge")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Button {
                        Task { await signUp() }
                    } label: {
                        HStack {
                            Spacer()
                            if authService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Create Account")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || authService.isLoading)
                    .accessibilityLabel("Create account")
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !username.isEmpty && !password.isEmpty
        && password == confirmPassword && password.count >= 8
    }

    private func signUp() async {
        error = nil
        guard password == confirmPassword else {
            error = "Passwords don't match"
            return
        }
        guard password.count >= 8 else {
            error = "Password must be at least 8 characters"
            return
        }

        do {
            try await authService.signUp(email: email, password: password, username: username)
            if authService.isAuthenticated {
                dismiss()
            } else {
                showVerificationMessage = true
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
