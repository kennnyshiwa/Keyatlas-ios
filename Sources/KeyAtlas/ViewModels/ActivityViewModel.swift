import Foundation

@Observable
final class ActivityViewModel: @unchecked Sendable {
    var activities: [Activity] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<Activity> = try await api.request(
                path: "/api/v1/activity",
                authenticated: true
            )
            await MainActor.run { self.activities = response.data }
        } catch {
            // Try data-wrapped array
            do {
                let response: APIDataResponse<[Activity]> = try await api.request(
                    path: "/api/v1/activity",
                    authenticated: true
                )
                await MainActor.run { self.activities = response.data }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}
