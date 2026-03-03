import Foundation

@Observable
final class DiscoverViewModel: @unchecked Sendable {
    var interestChecks: [Project] = []
    var groupBuys: [Project] = []
    var endingSoon: [Project] = []
    var newThisWeek: [Project] = []
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
            let response: PaginatedResponse<Project> = try await api.request(
                path: "/api/v1/projects",
                query: ["status": "GROUP_BUY", "sort": "ending_soon", "page_size": "10"]
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
}
