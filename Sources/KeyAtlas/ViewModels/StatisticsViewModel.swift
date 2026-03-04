import Foundation

@Observable
final class StatisticsViewModel: @unchecked Sendable {
    var stats: SiteStatistics?
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadStatistics() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: APIDataResponse<SiteStatistics> = try await api.request(path: "/api/v1/statistics")
            await MainActor.run { self.stats = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
