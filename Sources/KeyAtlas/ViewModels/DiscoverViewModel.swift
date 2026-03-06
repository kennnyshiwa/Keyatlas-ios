import Foundation

@Observable
final class DiscoverViewModel: @unchecked Sendable {
    var interestChecks: [Project] = []
    var groupBuys: [Project] = []
    var endingSoon: [Project] = []
    var newThisWeek: [Project] = []
    var recommendations: [Project] = []
    var recommendationLabel = "From projects you follow"
    var trendingThisWeek: [Project] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadAll() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadInterestChecks() }
            group.addTask { await self.loadGroupBuys() }
            group.addTask { await self.loadEndingSoon() }
            group.addTask { await self.loadNewThisWeek() }
            group.addTask { await self.loadPersonalizedLanes() }
            group.addTask { await self.loadTrendingThisWeek() }
        }
    }

    private func loadInterestChecks() async {
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["status": "INTEREST_CHECK", "sort": "newest", "page_size": "20"]
            )
            await MainActor.run { self.interestChecks = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func loadGroupBuys() async {
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["status": "GROUP_BUY", "sort": "newest", "page_size": "20"]
            )
            await MainActor.run { self.groupBuys = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func loadEndingSoon() async {
        do {
            // Match web logic exactly: GROUP_BUY projects with gbEndDate in next 7 days, sorted ascending by gbEndDate
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/discover/ending-soon",
                query: ["page_size": "10"]
            )
            await MainActor.run { self.endingSoon = response.data }
        } catch {
            // Silently fail — ending soon is supplementary
        }
    }

    private func loadNewThisWeek() async {
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects/latest",
                query: ["page_size": "10"]
            )
            await MainActor.run { self.newThisWeek = response.data }
        } catch {
            // Silently fail
        }
    }

    private func loadPersonalizedLanes() async {
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["sort": "newest", "page_size": "60"],
                authenticated: true
            )

            let followed = response.data.filter { $0.isFollowing == true }
            guard !followed.isEmpty else {
                await MainActor.run { self.recommendations = [] }
                return
            }

            let followedIDs = Set(followed.map(\.id))
            let followedCategoryIDs = Set(followed.compactMap(\.categoryId))
            let followedTags = Set(followed.flatMap { $0.tags ?? [] }.map { $0.lowercased() })

            let ranked = response.data
                .filter { !followedIDs.contains($0.id) }
                .map { project in
                    (project: project, score: recommendationScore(project: project, followedCategoryIDs: followedCategoryIDs, followedTags: followedTags))
                }
                .filter { $0.score > 0 }
                .sorted { lhs, rhs in
                    if lhs.score == rhs.score {
                        return lhs.project.updatedAt > rhs.project.updatedAt
                    }
                    return lhs.score > rhs.score
                }
                .prefix(10)
                .map(\.project)

            let topFollow = followed.first?.title ?? ""
            await MainActor.run {
                self.recommendationLabel = topFollow.isEmpty ? "From projects you follow" : "Because you follow \(topFollow)"
                self.recommendations = Array(ranked)
            }
        } catch {
            // Not signed in or no personalized data available
        }
    }

    private func recommendationScore(project: Project, followedCategoryIDs: Set<String>, followedTags: Set<String>) -> Int {
        var score = 0
        if let categoryId = project.categoryId, followedCategoryIDs.contains(categoryId) {
            score += 5
        }

        let projectTags = Set((project.tags ?? []).map { $0.lowercased() })
        score += followedTags.intersection(projectTags).count * 3
        score += (project.followCount ?? 0) / 20
        score += (project.favoriteCount ?? 0) / 20
        return score
    }

    private func loadTrendingThisWeek() async {
        do {
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["sort": "updated", "page_size": "40"]
            )

            let ranked = response.data
                .sorted { lhs, rhs in
                    if lhs.trendingScore == rhs.trendingScore {
                        return lhs.updatedAt > rhs.updatedAt
                    }
                    return lhs.trendingScore > rhs.trendingScore
                }
                .prefix(10)

            await MainActor.run {
                self.trendingThisWeek = Array(ranked)
            }
        } catch {
            // Silently fail
        }
    }
}
