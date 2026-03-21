import Foundation

@Observable
final class SearchViewModel: @unchecked Sendable {
    var query = ""
    var results: [Project] = []
    var vendorResults: [Vendor] = []
    var designerResults: [Designer] = []
    var isSearching = false
    var hasSearched = false

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await MainActor.run {
                self.results = []
                self.vendorResults = []
                self.designerResults = []
                self.hasSearched = false
            }
            return
        }

        await MainActor.run { self.isSearching = true }
        defer { Task { @MainActor in self.isSearching = false } }

        do {
            let response: SearchResponse = try await api.request(
                path: "/api/v1/search",
                query: ["q": trimmed, "limit": "30"]
            )
            await MainActor.run {
                self.results = response.data
                self.vendorResults = response.vendors ?? []
                self.designerResults = response.designers ?? []
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

    var hasAnyResults: Bool {
        !results.isEmpty || !vendorResults.isEmpty || !designerResults.isEmpty
    }
}

/// Search response that includes projects, vendors, and designers
struct SearchResponse: Codable, Sendable {
    let data: [Project]
    let vendors: [Vendor]?
    let designers: [Designer]?
}
