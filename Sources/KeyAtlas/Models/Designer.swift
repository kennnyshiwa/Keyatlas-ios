import Foundation

struct Designer: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let logoUrl: String?
    let bannerUrl: String?
    let websiteUrl: String?
    let projectCount: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case logoUrl = "logo_url"
        case bannerUrl = "banner_url"
        case websiteUrl = "website_url"
        case projectCount = "project_count"
        case createdAt = "created_at"
    }
}

/// Lightweight designer reference returned on project detail
struct DesignerProfile: Codable, Hashable, Sendable {
    let name: String
    let slug: String
}
