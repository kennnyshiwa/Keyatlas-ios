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

        do {
            let project: Project = try await api.request(
                path: "/api/v1/projects/\(slug)",
                authenticated: true
            )
            await MainActor.run { self.project = project }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
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

        struct CommentBody: Codable, Sendable {
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
