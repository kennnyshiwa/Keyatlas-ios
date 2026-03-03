import Foundation

@Observable
final class GuideViewModel: @unchecked Sendable {
    var guides: [Guide] = []
    var selectedGuide: Guide?
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadGuides() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<Guide> = try await api.request(path: "/api/v1/guides")
            await MainActor.run { self.guides = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func loadGuide(slug: String) async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let guide: Guide = try await api.request(path: "/api/v1/guides/\(slug)")
            await MainActor.run { self.selectedGuide = guide }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
