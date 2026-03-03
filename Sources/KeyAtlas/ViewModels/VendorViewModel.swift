import Foundation

@Observable
final class VendorListViewModel: @unchecked Sendable {
    var vendors: [Vendor] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadVendors() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<Vendor> = try await api.request(path: "/api/v1/vendors")
            await MainActor.run { self.vendors = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

@Observable
final class VendorDetailViewModel: @unchecked Sendable {
    var vendor: Vendor?
    var projects: [Project] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadVendor(slug: String) async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            struct VendorDetailResponse: Codable, Sendable {
                let vendor: Vendor
                let projects: [Project]?
            }
            let response: VendorDetailResponse = try await api.request(path: "/api/v1/vendors/\(slug)")
            await MainActor.run {
                self.vendor = response.vendor
                self.projects = response.projects ?? []
            }
        } catch {
            // Try plain vendor object
            do {
                let vendor: Vendor = try await api.request(path: "/api/v1/vendors/\(slug)")
                await MainActor.run { self.vendor = vendor }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}
