import Foundation

@Observable
final class DesignerListViewModel: @unchecked Sendable {
    var designers: [Designer] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadDesigners() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<Designer> = try await api.request(path: "/api/v1/designers")
            await MainActor.run { self.designers = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

@Observable
final class DesignerDetailViewModel: @unchecked Sendable {
    var designer: Designer?
    var projects: [Project] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func loadDesigner(slug: String) async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            struct DesignerPayload: Codable, Sendable {
                let data: DesignerData
            }
            struct DesignerProjectLite: Codable, Hashable, Sendable {
                let id: String?
                let title: String?
                let slug: String?
                let statusRaw: String?
                let heroImage: String?
                let createdAt: String?
                let updatedAt: String?

                enum CodingKeys: String, CodingKey {
                    case id, title, slug, status
                    case heroImage = "hero_image_url"
                    case createdAt = "created_at"
                    case updatedAt = "updated_at"
                }

                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    id = try c.decodeIfPresent(String.self, forKey: .id)
                    title = try c.decodeIfPresent(String.self, forKey: .title)
                    slug = try c.decodeIfPresent(String.self, forKey: .slug)
                    statusRaw = try c.decodeIfPresent(String.self, forKey: .status)
                    heroImage = try c.decodeIfPresent(String.self, forKey: .heroImage)
                    createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
                    updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
                }

                func encode(to encoder: Encoder) throws {
                    var c = encoder.container(keyedBy: CodingKeys.self)
                    try c.encodeIfPresent(id, forKey: .id)
                    try c.encodeIfPresent(title, forKey: .title)
                    try c.encodeIfPresent(slug, forKey: .slug)
                    try c.encodeIfPresent(statusRaw, forKey: .status)
                    try c.encodeIfPresent(heroImage, forKey: .heroImage)
                    try c.encodeIfPresent(createdAt, forKey: .createdAt)
                    try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
                }
            }

            struct DesignerData: Codable, Hashable, Sendable {
                let id: String
                let name: String
                let slug: String
                let description: String?
                let logoUrl: String?
                let bannerUrl: String?
                let websiteUrl: String?
                let createdAt: String?
                let projects: [DesignerProjectLite]?

                enum CodingKeys: String, CodingKey {
                    case id, name, slug, description, projects
                    case logoUrl = "logo_url"
                    case bannerUrl = "banner_url"
                    case websiteUrl = "website_url"
                    case createdAt = "created_at"
                }
            }

            let response: DesignerPayload = try await api.request(path: "/api/v1/designers/\(slug)")
            let d = response.data
            let mapped = Designer(
                id: d.id,
                name: d.name,
                slug: d.slug,
                description: d.description,
                logoUrl: d.logoUrl,
                bannerUrl: d.bannerUrl,
                websiteUrl: d.websiteUrl,
                projectCount: d.projects?.count,
                createdAt: d.createdAt
            )
            let nowISO = ISO8601DateFormatter().string(from: Date())
            let projectModels: [Project] = (d.projects ?? []).compactMap { p in
                guard let id = p.id, let title = p.title, let slug = p.slug else { return nil }
                let status = ProjectStatus(rawValue: p.statusRaw ?? "") ?? .interestCheck

                return Project(
                    id: id,
                    title: title,
                    slug: slug,
                    description: nil,
                    status: status,
                    heroImageUrl: p.heroImage,
                    category: nil,
                    categoryId: nil,
                    profile: nil,
                    designer: nil,
                    designerProfile: nil,
                    pricing: nil,
                    vendors: nil,
                    gallery: nil,
                    timeline: nil,
                    updates: nil,
                    comments: nil,
                    tags: nil,
                    links: nil,
                    soundTests: nil,
                    estimatedDelivery: nil,
                    gbStartDate: nil,
                    gbEndDate: nil,
                    followCount: nil,
                    favoriteCount: nil,
                    apiCommentCount: nil,
                    isFollowing: nil,
                    isFavorited: nil,
                    isFeatured: nil,
                    isInCollection: nil,
                    published: nil,
                    createdAt: p.createdAt ?? nowISO,
                    updatedAt: p.updatedAt ?? nowISO
                )
            }

            await MainActor.run {
                self.designer = mapped
                self.projects = projectModels
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
