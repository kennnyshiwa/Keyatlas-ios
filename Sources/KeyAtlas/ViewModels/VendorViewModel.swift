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
            struct VendorPayload: Codable, Hashable, Sendable {
                let data: VendorData
            }
            struct VendorData: Codable, Hashable, Sendable {
                let id: String
                let name: String
                let slug: String
                let description: String?
                let logo: String?
                let storefrontUrl: String?
                let verified: Bool?
                let regionsServed: [String]?
                let projects: [Project]?
            }

            let response: VendorPayload = try await api.request(path: "/api/v1/vendors/\(slug)")
            let v = response.data
            let mapped = Vendor(
                id: v.id,
                name: v.name,
                slug: v.slug,
                description: v.description,
                logoUrl: v.logo,
                websiteUrl: v.storefrontUrl,
                regions: v.regionsServed,
                projectCount: v.projects?.count,
                createdAt: nil
            )
            await MainActor.run {
                self.vendor = mapped
                self.projects = v.projects ?? []
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
