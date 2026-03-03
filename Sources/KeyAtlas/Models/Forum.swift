import Foundation

struct ForumCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let threadCount: Int?
    let postCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case threadCount
        case postCount
    }
}

struct ForumThread: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String?
    let content: String?
    let categoryId: String?
    let category: ForumCategory?
    let author: UserSummary?
    let postCount: Int?
    let isPinned: Bool?
    let isLocked: Bool?
    let lastPostAt: String?
    let createdAt: String
    let updatedAt: String?
    let posts: [ForumPost]?

    enum CodingKeys: String, CodingKey {
        case id, title, slug, content, category, author, posts
        case categoryId = "category_id"
        case postCount = "post_count"
        case isPinned = "is_pinned"
        case isLocked = "is_locked"
        case lastPostAt = "last_post_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ForumPost: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let content: String
    let author: UserSummary?
    let threadId: String?
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, content, author
        case threadId = "thread_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
