import Foundation

struct Guide: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let slug: String
    let description: String?
    let content: String?
    let heroImageUrl: String?
    let author: UserSummary?
    let tags: [String]?
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, content, author, tags
        case heroImageUrl = "hero_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
