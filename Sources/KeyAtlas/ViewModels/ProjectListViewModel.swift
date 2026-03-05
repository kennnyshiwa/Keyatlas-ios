import Foundation

enum ProjectSortOption: String, CaseIterable, Sendable {
    case newest = "newest"
    case oldest = "oldest"
    case gbNewest = "gb-newest"
    case gbOldest = "gb-oldest"
    case gbEnding = "gb-ending"
    case az = "a-z"
    case za = "z-a"
    case mostFollowed = "most-followed"
    case recentlyUpdated = "updated"

    var displayName: String {
        switch self {
        case .newest: "Newest"
        case .oldest: "Oldest"
        case .gbNewest: "GB Date (Newest)"
        case .gbOldest: "GB Date (Oldest)"
        case .gbEnding: "GB Ending Soon"
        case .az: "A → Z"
        case .za: "Z → A"
        case .mostFollowed: "Most Followed"
        case .recentlyUpdated: "Recently Updated"
        }
    }
}

@Observable
final class ProjectListViewModel: @unchecked Sendable {
    var projects: [Project] = []
    var isLoading = false
    var isLoadingMore = false
    var error: String?
    var hasMore = true
    var sortOption: ProjectSortOption = .newest
    var statusFilter: ProjectStatus?

    private var currentPage = 1
    private let pageSize = 20
    private let api = APIClient.shared

    func loadProjects(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMore = true
        }

        guard !isLoading else { return }

        if refresh {
            await MainActor.run { self.isLoading = true; self.error = nil }
        } else {
            await MainActor.run { self.isLoadingMore = true }
        }

        defer {
            Task { @MainActor in
                self.isLoading = false
                self.isLoadingMore = false
            }
        }

        do {
            var query: [String: String] = [
                "page": "\(currentPage)",
                "page_size": "\(pageSize)",
                "sort": sortOption.rawValue,
            ]
            if let status = statusFilter {
                query["status"] = status.rawValue
            }

            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: query,
                authenticated: true
            )

            await MainActor.run {
                if refresh {
                    self.projects = response.data
                } else {
                    self.projects.append(contentsOf: response.data)
                }
                self.hasMore = response.hasMore ?? (response.data.count >= self.pageSize)
                self.currentPage += 1
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        await loadProjects()
    }

    func refresh() async {
        await loadProjects(refresh: true)
    }

    func updateSort(_ option: ProjectSortOption) async {
        sortOption = option
        await loadProjects(refresh: true)
    }

    func updateFilter(_ status: ProjectStatus?) async {
        statusFilter = status
        await loadProjects(refresh: true)
    }
}
