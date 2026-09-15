import Foundation

@MainActor
@Observable
final class DiscoverViewModel: @unchecked Sendable {
    var interestChecks: [Project] = []
    var groupBuys: [Project] = []
    var endingSoon: [Project] = []
    var newThisWeek: [Project] = []
    private var personalProjects: [Project] = []
    private var personalUserID: String?
    private var personalSessionID: UUID?
    private var personalGeneration = 0
    var recommendations: [Project] {
        personalSessionID == SessionLifetime.shared.id && personalUserID == currentUserID() && personalUserID != nil ? personalProjects : []
    }
    private var personalLabel = "From projects you follow"
    var recommendationLabel: String {
        personalSessionID == SessionLifetime.shared.id && personalUserID == currentUserID() && personalUserID != nil
            ? personalLabel : "From projects you follow"
    }
    var trendingThisWeek: [Project] = []
    private struct Load: Equatable, Sendable {
        let generation: Int
        let sessionID: UUID
        let userID: String?
    }
    private var loadGeneration = 0
    private var activeLoad: Load?
    private var loading = false
    // Visible state belongs to this load even before a new view task runs.
    private var loadedError: String?
    var isLoading: Bool {
        activeLoad.map { owns($0) } == true && loading
    }
    var error: String? {
        activeLoad.map { owns($0) } == true ? loadedError : nil
    }

    private func owns(_ load: Load) -> Bool {
        activeLoad == load && SessionLifetime.shared.id == load.sessionID && currentUserID() == load.userID
    }

    private let api: APIClient
    private let currentUserID: @MainActor () -> String?

    init(api: APIClient = .shared, currentUserID: @escaping @MainActor () -> String? = { AuthService.shared.currentUser?.id }) {
        self.api = api
        self.currentUserID = currentUserID
    }

    func loadAll() async {
        loadGeneration += 1
        let load = Load(generation: loadGeneration, sessionID: SessionLifetime.shared.id, userID: currentUserID())
        activeLoad = load
        loading = true
        loadedError = nil
        // Synchronous, owned completion: an older load cannot stop a newer spinner.
        defer { if activeLoad == load { loading = false } }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadInterestChecks(load) }
            group.addTask { await self.loadGroupBuys(load) }
            group.addTask { await self.loadEndingSoon(load) }
            group.addTask { await self.loadNewThisWeek(load) }
            group.addTask { await self.loadPersonalizedLanes(load) }
            group.addTask { await self.loadTrendingThisWeek(load) }
        }
    }

    private func loadInterestChecks(_ load: Load) async {
        guard owns(load), !Task.isCancelled else { return }
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["status": "INTEREST_CHECK", "sort": "newest", "page_size": "20"], expectedSessionID: load.sessionID
            )
            guard owns(load), !Task.isCancelled else { return }
            interestChecks = response.data
        } catch {
            guard owns(load), !Task.isCancelled else { return }
            loadedError = error.localizedDescription
        }
    }

    private func loadGroupBuys(_ load: Load) async {
        guard owns(load), !Task.isCancelled else { return }
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["status": "GROUP_BUY", "sort": "newest", "page_size": "20"], expectedSessionID: load.sessionID
            )
            guard owns(load), !Task.isCancelled else { return }
            groupBuys = response.data
        } catch {
            guard owns(load), !Task.isCancelled else { return }
            loadedError = error.localizedDescription
        }
    }

    private func loadEndingSoon(_ load: Load) async {
        guard owns(load), !Task.isCancelled else { return }
        do {
            // Match web logic exactly: GROUP_BUY projects with gbEndDate in next 7 days, sorted ascending by gbEndDate
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/discover/ending-soon",
                query: ["page_size": "10"], expectedSessionID: load.sessionID
            )
            guard owns(load), !Task.isCancelled else { return }
            endingSoon = response.data
        } catch {
            // Silently fail — ending soon is supplementary
        }
    }

    private func loadNewThisWeek(_ load: Load) async {
        guard owns(load), !Task.isCancelled else { return }
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects/latest",
                query: ["page_size": "10"], expectedSessionID: load.sessionID
            )
            guard owns(load), !Task.isCancelled else { return }
            newThisWeek = response.data
        } catch {
            // Silently fail
        }
    }

    private func loadPersonalizedLanes(_ load: Load) async {
        guard owns(load), !Task.isCancelled else { return }
        await loadPersonalizedLanes()
    }

    func loadPersonalizedLanes() async {
        personalGeneration += 1
        let generation = personalGeneration
        let sessionID = SessionLifetime.shared.id
        personalSessionID = sessionID
        let userID = currentUserID()
        personalUserID = userID
        personalProjects = []
        personalLabel = "From projects you follow"
        guard userID != nil else { return }
        do {
            let response: RecommendedProjectsResponse = try await api.request(
                path: "/api/v1/discover/recommended", authenticated: true
            )
            guard generation == personalGeneration, SessionLifetime.shared.id == sessionID, currentUserID() == userID, !Task.isCancelled else { return }
            guard let title = response.anchorTitle else { return }
            personalLabel = "Because you follow \(title)"
            personalProjects = response.data
        } catch {
            // Empty on auth failure, no-follow, or endpoint error; never retain
            // old personal cards. A newer load owns its own results.
            guard generation == personalGeneration, SessionLifetime.shared.id == sessionID, currentUserID() == userID else { return }
            personalProjects = []
            personalLabel = "From projects you follow"
        }
    }

    private func loadTrendingThisWeek(_ load: Load) async {
        guard owns(load), !Task.isCancelled else { return }
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["sort": "updated", "page_size": "40"], expectedSessionID: load.sessionID
            )

            let ranked = response.data
                .sorted { lhs, rhs in
                    if lhs.trendingScore == rhs.trendingScore {
                        return (lhs.updatedAt ?? "") > (rhs.updatedAt ?? "")
                    }
                    return lhs.trendingScore > rhs.trendingScore
                }
                .prefix(10)

            guard owns(load), !Task.isCancelled else { return }
            trendingThisWeek = Array(ranked)
        } catch {
            // Silently fail
        }
    }
}

struct RecommendedProjectsResponse: Codable, Sendable {
    let anchorTitle: String?
    let data: [Project]

    enum CodingKeys: String, CodingKey {
        case anchorTitle = "anchor_title"
        case data
    }
}
