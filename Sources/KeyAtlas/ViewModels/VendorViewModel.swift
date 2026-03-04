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
            struct VendorProjectLite: Codable, Hashable, Sendable {
                let id: String
                let title: String
                let slug: String
                let status: ProjectStatus
                let heroImage: String?
                let createdAt: String?
                let updatedAt: String?

                enum CodingKeys: String, CodingKey {
                    case id, title, slug, status
                    case heroImage = "hero_image_url"
                    case createdAt = "created_at"
                    case updatedAt = "updated_at"
                }
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
                let projects: [VendorProjectLite]?
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
            let nowISO = ISO8601DateFormatter().string(from: Date())
            let projectModels: [Project] = (v.projects ?? []).map { p in
                Project(
                    id: p.id,
                    title: p.title,
                    slug: p.slug,
                    description: nil,
                    status: p.status,
                    heroImageUrl: p.heroImage,
                    category: nil,
                    categoryId: nil,
                    designer: nil,
                    pricing: nil,
                    vendors: nil,
                    gallery: nil,
                    timeline: nil,
                    updates: nil,
                    comments: nil,
                    tags: nil,
                    links: nil,
                    estimatedDelivery: nil,
                    gbStartDate: nil,
                    gbEndDate: nil,
                    followCount: nil,
                    favoriteCount: nil,
                    isFollowing: nil,
                    isFavorited: nil,
                    isFeatured: nil,
                    createdAt: p.createdAt ?? nowISO,
                    updatedAt: p.updatedAt ?? nowISO
                )
            }

            await MainActor.run {
                self.vendor = mapped
                self.projects = projectModels
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
