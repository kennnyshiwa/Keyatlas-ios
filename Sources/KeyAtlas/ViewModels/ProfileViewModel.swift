import Foundation

@Observable
final class ProfileViewModel: @unchecked Sendable {
    var profile: UserProfile?
    var isLoading = false
    var error: String?
    var notifications: [AppNotification] = []

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
            await MainActor.run { self.notifications = response.data }
        } catch {
            // Silently fail
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
