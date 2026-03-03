import Foundation

@Observable
final class SearchViewModel: @unchecked Sendable {
    var query = ""
    var results: [Project] = []
    var isSearching = false
    var hasSearched = false

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await MainActor.run {
                self.results = []
                self.hasSearched = false
            }
            return
        }

        await MainActor.run { self.isSearching = true }
        defer { Task { @MainActor in self.isSearching = false } }

        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["q": trimmed, "page_size": "30"]
            )
            await MainActor.run {
                self.results = response.data
                self.hasSearched = true
            }
        } catch {
            await MainActor.run { self.hasSearched = true }
        }
    }

    /// Debounced search — call from onChange of query
    func debouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search()
        }
    }
}
