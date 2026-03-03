import Foundation

@Observable
final class ProjectDetailViewModel: @unchecked Sendable {
    var project: Project?
    var isLoading = false
    var error: String?
    var isTogglingFollow = false
    var isTogglingFavorite = false
    var commentText = ""
    var isPostingComment = false

    private let api = APIClient.shared

    func loadProject(slug: String) async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        let safeSlug = normalizedSlug(slug)
        guard !safeSlug.isEmpty else {
            await MainActor.run { self.error = "Invalid project link" }
            return
        }

        do {
            let response: APIDataResponse<Project> = try await api.request(
                path: "/api/v1/projects/\(safeSlug)",
                authenticated: false
            )
            await MainActor.run { self.project = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func normalizedSlug(_ raw: String) -> String {
        if let url = URL(string: raw), let host = url.host, !host.isEmpty {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.hasPrefix("projects/") {
                return String(path.dropFirst("projects/".count))
            }
            if path.hasPrefix("api/auth/mobile/callback") {
                return ""
            }
            if let last = path.split(separator: "/").last {
                return String(last)
            }
        }
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func toggleFollow() async {
        guard let project else { return }
        await MainActor.run { self.isTogglingFollow = true }
        defer { Task { @MainActor in self.isTogglingFollow = false } }

        let isCurrentlyFollowing = project.isFollowing ?? false
        let method: HTTPMethod = isCurrentlyFollowing ? .delete : .post

        do {
            try await api.requestVoid(method, path: "/api/v1/projects/\(project.slug)/follow")
            await loadProject(slug: project.slug)
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func toggleFavorite() async {
        guard let project else { return }
        await MainActor.run { self.isTogglingFavorite = true }
        defer { Task { @MainActor in self.isTogglingFavorite = false } }

        let isCurrentlyFavorited = project.isFavorited ?? false
        let method: HTTPMethod = isCurrentlyFavorited ? .delete : .post

        do {
            try await api.requestVoid(method, path: "/api/v1/projects/\(project.slug)/favorite")
            await loadProject(slug: project.slug)
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func postComment() async {
        guard let project, !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await MainActor.run { self.isPostingComment = true }
        defer { Task { @MainActor in self.isPostingComment = false } }

        struct CommentBody: Codable, Hashable, Sendable {
            let content: String
        }

        do {
            try await api.requestVoid(
                .post,
                path: "/api/v1/projects/\(project.slug)/comments",
                body: CommentBody(content: commentText)
            )
            await MainActor.run { self.commentText = "" }
            await loadProject(slug: project.slug)
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
