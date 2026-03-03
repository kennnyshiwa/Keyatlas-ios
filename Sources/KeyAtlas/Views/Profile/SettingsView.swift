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
    @State private var notifyFollowed = true
    @State private var notifyStatusChange = true
    @State private var notifyComments = true

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
                    Toggle("Followed project updates", isOn: $notifyFollowed)
                        .accessibilityLabel("Notify on followed project updates")
                    Toggle("Status changes", isOn: $notifyStatusChange)
                        .accessibilityLabel("Notify on status changes")
                    Toggle("Comments on my projects", isOn: $notifyComments)
                        .accessibilityLabel("Notify on comments")
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
            }
        }
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

            // Save notification prefs
            struct NotifPrefs: Codable, Hashable, Sendable {
                let followedUpdates: Bool
                let statusChanges: Bool
                let comments: Bool

                enum CodingKeys: String, CodingKey {
                    case followedUpdates = "followed_updates"
                    case statusChanges = "status_changes"
                    case comments
                }
            }

            try await APIClient.shared.requestVoid(
                .put,
                path: "/api/v1/users/me/notifications",
                body: NotifPrefs(
                    followedUpdates: notifyFollowed,
                    statusChanges: notifyStatusChange,
                    comments: notifyComments
                )
            )

            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
