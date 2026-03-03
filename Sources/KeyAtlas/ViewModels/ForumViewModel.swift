import Foundation

@Observable
final class ForumViewModel: @unchecked Sendable {
    var categories: [ForumCategory] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadCategories() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            struct CategoriesResponse: Codable, Hashable, Sendable { let data: [ForumCategory] }
            let response: CategoriesResponse = try await api.request(path: "/api/v1/forums/categories")
            await MainActor.run { self.categories = response.data }
        } catch {
            // Try array directly
            do {
                let cats: [ForumCategory] = try await api.request(path: "/api/v1/forums/categories")
                await MainActor.run { self.categories = cats }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

@Observable
final class ThreadListViewModel: @unchecked Sendable {
    var threads: [ForumThread] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadThreads(categoryId: String) async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            struct ThreadsResponse: Codable, Hashable, Sendable { let data: [ForumThread] }
            let response: ThreadsResponse = try await api.request(
                path: "/api/v1/forums/categories/\(categoryId)/threads"
            )
            await MainActor.run { self.threads = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

@Observable
final class ThreadDetailViewModel: @unchecked Sendable {
    var thread: ForumThread?
    var isLoading = false
    var error: String?
    var replyText = ""
    var isPosting = false

    private let api = APIClient.shared

    func loadThread(id: String) async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let thread: ForumThread = try await api.request(path: "/api/v1/forums/threads/\(id)")
            await MainActor.run { self.thread = thread }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func postReply() async {
        guard let thread, !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await MainActor.run { self.isPosting = true }
        defer { Task { @MainActor in self.isPosting = false } }

        struct ReplyBody: Codable, Hashable, Sendable { let content: String }

        do {
            try await api.requestVoid(
                .post,
                path: "/api/v1/forums/threads/\(thread.id)/posts",
                body: ReplyBody(content: replyText)
            )
            await MainActor.run { self.replyText = "" }
            await loadThread(id: thread.id)
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
