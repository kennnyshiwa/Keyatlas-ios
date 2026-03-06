import SwiftUI

private func normalizeProfileProjectSlug(_ raw: String) -> String {
    if let url = URL(string: raw), let host = url.host, !host.isEmpty {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasPrefix("projects/") {
            return String(path.dropFirst("projects/".count))
        }
        if path.hasPrefix("api/auth/mobile/callback") {
            return ""
        }
        if let last = path.split(separator: "/").last, !last.isEmpty {
            return String(last)
        }
    }
    return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
}

private struct ProfileProjectRow: View {
    let project: Project

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CachedImage(url: project.heroImageUrl)
                .frame(width: 92, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(project.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ProfileTabView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = ProfileViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if !authService.isAuthenticated {
                    LoginView()
                } else if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView("Loading profile…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profile = viewModel.profile {
                    profileContent(profile)
                } else if let error = viewModel.error {
                    ErrorView(message: error) { await viewModel.loadCurrentProfile() }
                } else {
                    // Authenticated but no profile loaded yet
                    ProgressView()
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                if authService.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                if authService.isAuthenticated {
                    await viewModel.loadCurrentProfile()
                }
            }
        }
    }

    @ViewBuilder
    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Avatar + info
                VStack(spacing: 12) {
                    AvatarImage(url: profile.effectiveAvatarUrl, size: 80)

                    Text(profile.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Stats row
                    HStack(spacing: 32) {
                        statItem(label: "Followers", count: profile.followerCount ?? 0)
                        statItem(label: "Following", count: profile.followingCount ?? 0)
                        statItem(label: "Projects", count: profile.projects?.count ?? 0)
                    }
                }
                .padding()

                // Admin section
                if authService.currentUser?.isAdmin == true {
                    NavigationLink {
                        AdminDashboardView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "shield.checkered")
                                .font(.title3)
                                .foregroundStyle(.red)
                            Text("Admin Panel")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                // User's projects
                if let projects = profile.projects, !projects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Projects")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(projects) { project in
                            let safeSlug = normalizeProfileProjectSlug(project.slug)
                            Group {
                                if safeSlug.isEmpty {
                                    ProfileProjectRow(project: project)
                                } else {
                                    NavigationLink {
                                        ProjectDetailView(slug: safeSlug)
                                    } label: {
                                        ProfileProjectRow(project: project)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                        }
                    }
                }

                // Notifications
                if !viewModel.notifications.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notifications")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.notifications) { notification in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(notification.isRead ? .clear : .blue)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lifecycleLabel(for: notification.type))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(notification.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(notification.message)
                                        .font(.subheadline)
                                    Text(notification.createdAt.relativeTime)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.loadCurrentProfile()
            await viewModel.loadNotifications()
        }
    }

    private func lifecycleLabel(for type: String) -> String {
        switch type {
        case "PROJECT_STATUS_CHANGE":
            return "Project Status"
        case "PROJECT_GB_ENDING_SOON":
            return "Group Buy Ending Soon"
        default:
            return "Notification"
        }
    }

    private func statItem(label: String, count: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("\(count) \(label)")
    }
}

/// Public profile view (for viewing other users)
struct PublicProfileView: View {
    let username: String
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.profile == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error {
                ErrorView(message: error) { await viewModel.loadProfile(username: username) }
            } else if let profile = viewModel.profile {
                ScrollView {
                    VStack(spacing: 16) {
                        AvatarImage(url: profile.effectiveAvatarUrl, size: 80)
                        Text(profile.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        if let bio = profile.bio {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 32) {
                            VStack {
                                Text("\(profile.followerCount ?? 0)")
                                    .font(.headline)
                                Text("Followers")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text("\(profile.followingCount ?? 0)")
                                    .font(.headline)
                                Text("Following")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            Task {
                                await viewModel.toggleFollow(
                                    username: username,
                                    isFollowing: profile.isFollowing ?? false
                                )
                            }
                        } label: {
                            Text(profile.isFollowing == true ? "Unfollow" : "Follow")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(profile.isFollowing == true ? .gray : .blue)
                        .padding(.horizontal)

                        if let projects = profile.projects, !projects.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Projects")
                                    .font(.headline)
                                    .padding(.horizontal)
                                ForEach(projects) { project in
                                    let safeSlug = normalizeProfileProjectSlug(project.slug)
                                    Group {
                                        if safeSlug.isEmpty {
                                            ProfileProjectRow(project: project)
                                        } else {
                                            NavigationLink {
                                                ProjectDetailView(slug: safeSlug)
                                            } label: {
                                                ProfileProjectRow(project: project)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadProfile(username: username) }
    }

    private func normalizeProfileProjectSlug(_ raw: String) -> String {
        // Defensive: some payloads may send full URLs instead of slugs
        if let url = URL(string: raw), let host = url.host, !host.isEmpty {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.hasPrefix("projects/") {
                return String(path.dropFirst("projects/".count))
            }

            // Ignore auth callback URLs accidentally stored in content fields
            if path.hasPrefix("api/auth/mobile/callback") {
                return ""
            }

            if let last = path.split(separator: "/").last, !last.isEmpty {
                return String(last)
            }
        }
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
