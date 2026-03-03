import Foundation

struct Vendor: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let logoUrl: String?
    let websiteUrl: String?
    let regions: [String]?
    let projectCount: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, regions
        case logoUrl = "logo_url"
        case websiteUrl = "website_url"
        case projectCount = "project_count"
        case createdAt = "created_at"
    }
}
