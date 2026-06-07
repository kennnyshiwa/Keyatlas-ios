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

    private enum AlternateCodingKeys: String, CodingKey {
        case categoryId
        case postCount
        case pinned
        case locked
        case lastPostAt
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let alternate = try decoder.container(keyedBy: AlternateCodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        category = try container.decodeIfPresent(ForumCategory.self, forKey: .category)
        author = try container.decodeIfPresent(UserSummary.self, forKey: .author)
        posts = try container.decodeIfPresent([ForumPost].self, forKey: .posts)

        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
            ?? alternate.decodeIfPresent(String.self, forKey: .categoryId)
        postCount = try container.decodeIfPresent(Int.self, forKey: .postCount)
            ?? alternate.decodeIfPresent(Int.self, forKey: .postCount)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned)
            ?? alternate.decodeIfPresent(Bool.self, forKey: .pinned)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked)
            ?? alternate.decodeIfPresent(Bool.self, forKey: .locked)
        lastPostAt = try container.decodeIfPresent(String.self, forKey: .lastPostAt)
            ?? alternate.decodeIfPresent(String.self, forKey: .lastPostAt)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? alternate.decodeIfPresent(String.self, forKey: .createdAt)
            ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            ?? alternate.decodeIfPresent(String.self, forKey: .updatedAt)
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

    private enum AlternateCodingKeys: String, CodingKey {
        case threadId
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let alternate = try decoder.container(keyedBy: AlternateCodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        author = try container.decodeIfPresent(UserSummary.self, forKey: .author)
        threadId = try container.decodeIfPresent(String.self, forKey: .threadId)
            ?? alternate.decodeIfPresent(String.self, forKey: .threadId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? alternate.decodeIfPresent(String.self, forKey: .createdAt)
            ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            ?? alternate.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}
