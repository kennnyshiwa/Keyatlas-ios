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

@MainActor
@Observable
final class ProjectListViewModel: @unchecked Sendable {
    private var loadedProjects: [Project] = []
    private var loadedUserID: String?
    private var loadedSessionID: UUID?
    private var generation = 0
    var projects: [Project] {
        loadedSessionID == SessionLifetime.shared.id && loadedUserID == currentUserID() ? loadedProjects : []
    }
    var isLoading = false
    var isLoadingMore = false
    private var loadedError: String?
    var error: String? {
        loadedSessionID == SessionLifetime.shared.id && loadedUserID == currentUserID() ? loadedError : nil
    }
    var hasMore = true
    var sortOption: ProjectSortOption = .newest
    var statusFilter: ProjectStatus?

    private var currentPage = 1
    private let pageSize = 20
    private let api: APIClient
    private let currentUserID: @MainActor () -> String?

    init(api: APIClient = .shared, currentUserID: @escaping @MainActor () -> String? = { AuthService.shared.currentUser?.id }) {
        self.api = api
        self.currentUserID = currentUserID
    }

    var followedProjects: [Project] {
        projects.filter { $0.isFollowing == true }
    }

    var recommendationLabel: String {
        if let first = followedProjects.first {
            return "Because you follow \(first.title)"
        }
        return "From projects you follow"
    }

    var recommendedProjects: [Project] {
        let followedIDs = Set(followedProjects.map(\.id))
        let followedCategories = Set(followedProjects.compactMap(\.categoryId))

        return projects
            .filter { !followedIDs.contains($0.id) }
            .filter { project in
                guard let category = project.categoryId else { return false }
                return followedCategories.contains(category)
            }
            .prefix(8)
            .map { $0 }
    }

    var trendingProjects: [Project] {
        Array(projects.sorted { $0.trendingScore > $1.trendingScore }.prefix(8))
    }

    func loadProjects(refresh: Bool = false) async {
        let sessionID = SessionLifetime.shared.id
        let userID = currentUserID()
        let accountChanged = loadedUserID != userID || loadedSessionID != sessionID
        let reset = refresh || accountChanged
        guard reset || (!isLoading && !isLoadingMore) else { return }
        generation += 1
        let requestGeneration = generation
        if reset {
            currentPage = 1
            hasMore = true
            if accountChanged { loadedProjects = [] }
            loadedUserID = userID
            loadedSessionID = sessionID
            isLoading = true
            isLoadingMore = false
            loadedError = nil
        } else {
            isLoadingMore = true
        }
        defer {
            if generation == requestGeneration {
                isLoading = false
                isLoadingMore = false
            }
        }
        do {
            var query = ["page": "\(currentPage)", "page_size": "\(pageSize)", "sort": sortOption.rawValue]
            if let status = statusFilter { query["status"] = status.rawValue }
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects", query: query, authenticated: userID != nil
            )
            guard generation == requestGeneration, SessionLifetime.shared.id == sessionID, currentUserID() == userID, !Task.isCancelled else { return }
            if reset { loadedProjects = response.data }
            else { loadedProjects.append(contentsOf: response.data) }
            hasMore = response.hasMore ?? (response.data.count >= pageSize)
            currentPage += 1
        } catch {
            guard generation == requestGeneration, SessionLifetime.shared.id == sessionID, currentUserID() == userID else { return }
            self.loadedError = error.localizedDescription
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
