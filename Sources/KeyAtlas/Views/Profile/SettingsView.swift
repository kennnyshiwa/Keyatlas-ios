import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var bio = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var isSaving = false
    @State private var error: String?
    @State private var showSignOutConfirm = false

    // Notification prefs
    @State private var notifyProjectStatusChanges = true
    @State private var notifyGbEndingSoon = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        if let data = avatarData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            AvatarImage(url: authService.currentUser?.effectiveAvatarUrl, size: 60)
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Change Avatar")
                        }
                        .accessibilityLabel("Change profile picture")
                    }

                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Username")

                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Bio")
                }

                Section("Notifications") {
                    Toggle("Project status changes", isOn: $notifyProjectStatusChanges)
                        .accessibilityLabel("Notify on project status changes")
                    Toggle("Group buys ending soon", isOn: $notifyGbEndingSoon)
                        .accessibilityLabel("Notify on group buys ending soon")
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Save Changes") {
                        Task { await saveProfile() }
                    }
                    .disabled(isSaving)
                    .accessibilityLabel("Save profile changes")
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showSignOutConfirm = true
                    }
                    .accessibilityLabel("Sign out")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authService.signOut()
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
            .onAppear {
                username = authService.currentUser?.username ?? ""
                Task { await loadNotificationPreferences() }
            }
        }
    }

    private func loadNotificationPreferences() async {
        struct Preference: Codable, Hashable, Sendable {
            let type: String
            let inApp: Bool
            let email: Bool
        }

        struct Response: Codable, Hashable, Sendable {
            let data: [Preference]
        }

        do {
            let response: Response = try await APIClient.shared.request(
                path: "/api/v1/notification-preferences",
                authenticated: true
            )
            if let status = response.data.first(where: { $0.type == "PROJECT_STATUS_CHANGES" }) {
                notifyProjectStatusChanges = status.inApp || status.email
            }
            if let gbEndingSoon = response.data.first(where: { $0.type == "PROJECT_GB_ENDING_SOON" }) {
                notifyGbEndingSoon = gbEndingSoon.inApp || gbEndingSoon.email
            }
        } catch {
            // Keep defaults if preferences are unavailable
        }
    }

    private func updateNotificationPreference(type: String, enabled: Bool) async throws {
        struct UpdateBody: Codable, Hashable, Sendable {
            let type: String
            let inApp: Bool
            let email: Bool
        }

        _ = try await APIClient.shared.request(
            .patch,
            path: "/api/v1/notification-preferences",
            body: UpdateBody(type: type, inApp: enabled, email: enabled),
            authenticated: true
        ) as EmptyResponse
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }
        error = nil

        // Upload avatar if changed
        if let avatarData {
            do {
                let _ = try await APIClient.shared.upload(
                    path: "/api/v1/users/me/avatar",
                    imageData: avatarData,
                    filename: "avatar.jpg"
                )
            } catch {
                self.error = "Avatar upload failed: \(error.localizedDescription)"
                return
            }
        }

        // Save profile fields
        struct ProfileUpdate: Codable, Hashable, Sendable {
            let username: String?
            let bio: String?
        }

        do {
            try await APIClient.shared.requestVoid(
                .patch,
                path: "/api/v1/users/me",
                body: ProfileUpdate(
                    username: username.isEmpty ? nil : username,
                    bio: bio.isEmpty ? nil : bio
                )
            )

            try await updateNotificationPreference(type: "PROJECT_STATUS_CHANGES", enabled: notifyProjectStatusChanges)
            try await updateNotificationPreference(type: "PROJECT_GB_ENDING_SOON", enabled: notifyGbEndingSoon)

            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
