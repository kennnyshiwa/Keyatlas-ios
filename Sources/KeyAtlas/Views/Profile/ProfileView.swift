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

enum ProfileSection: String, CaseIterable {
    case projects = "Projects"
    case favorites = "Favorites"
    case collection = "Collection"
    case notifications = "Notifications"
}

struct ProfileTabView: View {
    @Environment(AuthService.self) private var authService
    @State private var viewModel = ProfileViewModel()
    @State private var showSettings = false
    @State private var selectedSection: ProfileSection = .projects

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
                    await viewModel.loadNotifications()
                    await viewModel.loadFavorites()
                    await viewModel.loadCollection()
                }
            }
        }
    }

    @ViewBuilder
    private func profileContent(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            // Header (non-scrolling)
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

                HStack(spacing: 32) {
                    statItem(label: "Followers", count: profile.followerCount ?? 0)
                    statItem(label: "Following", count: profile.followingCount ?? 0)
                    statItem(label: "Projects", count: profile.projects?.count ?? 0)
                }
            }
            .padding()

            // Tab picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(ProfileSection.allCases, id: \.self) { section in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedSection = section }
                        } label: {
                            VStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Text(section.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(selectedSection == section ? .semibold : .regular)
                                    if section == .notifications {
                                        let unread = viewModel.notifications.filter { !$0.isRead }.count
                                        if unread > 0 {
                                            Text("\(unread)")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(.red))
                                        }
                                    } else {
                                        let count = sectionCount(section, profile: profile)
                                        if count > 0 {
                                            Text("\(count)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .foregroundStyle(selectedSection == section ? .primary : .secondary)

                                Rectangle()
                                    .fill(selectedSection == section ? Color.accentColor : .clear)
                                    .frame(height: 2)
                            }
                            .padding(.horizontal, 16)
                        }
                        .accessibilityLabel("\(section.rawValue) tab")
                    }
                }
            }

            Divider()

            // Tab content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedSection {
                    case .projects:
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

                        // Activity link
                        NavigationLink {
                            ActivityView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bolt.horizontal")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                Text("Activity Feed")
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

                        if let projects = profile.projects, !projects.isEmpty {
                            projectList(projects)
                        } else {
                            emptyTab(title: "No projects yet", message: "Submit your first project to get started.", icon: "keyboard")
                        }

                    case .favorites:
                        if !viewModel.favorites.isEmpty {
                            projectList(viewModel.favorites)
                        } else {
                            emptyTab(title: "No favorites yet", message: "Heart projects you like to save them here.", icon: "heart")
                        }

                    case .collection:
                        if !viewModel.collection.isEmpty {
                            projectList(viewModel.collection)
                        } else {
                            emptyTab(title: "No items in collection", message: "Add projects to your collection to track them here.", icon: "tray")
                        }

                    case .notifications:
                        if !viewModel.notifications.isEmpty {
                            let unreadCount = viewModel.notifications.filter { !$0.isRead }.count

                            HStack {
                                Text(unreadCount > 0 ? "\(unreadCount) unread" : "All caught up")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    Task { await viewModel.markAllNotificationsAsRead() }
                                } label: {
                                    if viewModel.isMarkingAllRead {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Text("Mark all as read")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(unreadCount == 0 || viewModel.isMarkingAllRead)
                                .accessibilityLabel("Mark all notifications as read")
                            }
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
                        } else {
                            emptyTab(title: "No notifications", message: "You're all caught up.", icon: "bell")
                        }
                    }
                }
                .padding(.top, 12)
            }
            .refreshable {
                await viewModel.loadCurrentProfile()
                await viewModel.loadNotifications()
                await viewModel.loadFavorites()
                await viewModel.loadCollection()
            }
        }
    }

    private func sectionCount(_ section: ProfileSection, profile: UserProfile) -> Int {
        switch section {
        case .projects: return profile.projects?.count ?? 0
        case .favorites: return viewModel.favorites.count
        case .collection: return viewModel.collection.count
        case .notifications: return viewModel.notifications.count
        }
    }

    @ViewBuilder
    private func projectList(_ projects: [Project]) -> some View {
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

    @ViewBuilder
    private func emptyTab(title: String, message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
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
