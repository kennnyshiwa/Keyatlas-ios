import Foundation

@Observable
final class ProfileViewModel: @unchecked Sendable {
    var profile: UserProfile?
    var isLoading = false
    var error: String?
    var notifications: [AppNotification] = []
    var favorites: [Project] = []
    var collection: [Project] = []
    var unreadNotificationCount: Int = 0
    var isMarkingAllRead = false

    private let api = APIClient.shared

    func loadProfile(username: String) async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let profile: UserProfile = try await api.request(path: "/api/v1/users/\(username)")
            await MainActor.run { self.profile = profile }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func loadCurrentProfile() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: APIDataResponse<UserProfile> = try await api.request(path: "/api/v1/profile", authenticated: true)
            await MainActor.run { self.profile = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func loadNotifications() async {
        do {
            struct NotifResponse: Codable, Hashable, Sendable { let data: [AppNotification] }
            let response: NotifResponse = try await api.request(
                path: "/api/v1/notifications",
                authenticated: true
            )
            await MainActor.run {
                self.notifications = response.data
                self.unreadNotificationCount = response.data.filter { !$0.isRead }.count
            }
        } catch {
            // Silently fail
        }
    }

    func loadFavorites() async {
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/profile/favorites",
                authenticated: true
            )
            await MainActor.run { self.favorites = response.data }
        } catch {
            // Try alternate structure
            do {
                let response: APIDataResponse<[Project]> = try await api.request(
                    path: "/api/v1/profile/favorites",
                    authenticated: true
                )
                await MainActor.run { self.favorites = response.data }
            } catch {
                // Silently fail
            }
        }
    }

    func loadCollection() async {
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/profile/collection",
                authenticated: true
            )
            await MainActor.run { self.collection = response.data }
        } catch {
            // Try alternate structure
            do {
                let response: APIDataResponse<[Project]> = try await api.request(
                    path: "/api/v1/profile/collection",
                    authenticated: true
                )
                await MainActor.run { self.collection = response.data }
            } catch {
                // Silently fail
            }
        }
    }

    func markAllNotificationsAsRead() async {
        guard !isMarkingAllRead else { return }
        await MainActor.run { self.isMarkingAllRead = true }
        defer { Task { @MainActor in self.isMarkingAllRead = false } }

        let paths = [
            "/api/v1/notifications/mark-all-read",
            "/api/v1/notifications/read-all",
            "/api/v1/notifications/mark_read"
        ]

        var succeeded = false
        for path in paths {
            do {
                try await api.requestVoid(.post, path: path, authenticated: true)
                succeeded = true
                break
            } catch {
                continue
            }
        }

        if succeeded {
            await loadNotifications()
        } else {
            await MainActor.run {
                self.error = "Couldn't mark all notifications as read right now."
            }
        }
    }

    func toggleFollow(username: String, isFollowing: Bool) async {
        let method: HTTPMethod = isFollowing ? .delete : .post
        do {
            try await api.requestVoid(method, path: "/api/v1/users/\(username)/follow")
            await loadProfile(username: username)
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
