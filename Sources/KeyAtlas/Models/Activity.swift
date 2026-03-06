import Foundation

/// Activity item from the user's feed
struct Activity: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let type: String
    let title: String?
    let message: String?
    let createdAt: String
    let project: ActivityProject?
    let user: ActivityUser?

    enum CodingKeys: String, CodingKey {
        case id, type, title, message, project, user
        case createdAt = "created_at"
        case createdAtCamel = "createdAt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        project = try? container.decodeIfPresent(ActivityProject.self, forKey: .project)
        user = try? container.decodeIfPresent(ActivityUser.self, forKey: .user)
        createdAt = (try? container.decode(String.self, forKey: .createdAt))
            ?? (try? container.decode(String.self, forKey: .createdAtCamel))
            ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(project, forKey: .project)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encode(createdAt, forKey: .createdAt)
    }

    var typeDisplayName: String {
        switch type {
        case "new_project": return "New Project"
        case "comment": return "Comment"
        case "forum_thread": return "Forum Thread"
        case "project_update": return "Project Update"
        case "FOLLOW", "follow": return "Follow"
        case "STATUS_CHANGE", "status_change": return "Status Change"
        default: return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var typeIcon: String {
        switch type {
        case "new_project": return "plus.circle"
        case "comment": return "bubble.left"
        case "forum_thread": return "bubble.left.and.bubble.right"
        case "project_update": return "bell"
        case "FOLLOW", "follow": return "person.badge.plus"
        case "STATUS_CHANGE", "status_change": return "arrow.triangle.2.circlepath"
        default: return "bolt"
        }
    }
}

struct ActivityProject: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String?
    let slug: String?
    let heroImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, slug
        case heroImageUrl = "hero_image_url"
        case heroImageUrlCamel = "heroImageUrl"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        slug = try? container.decodeIfPresent(String.self, forKey: .slug)
        heroImageUrl = (try? container.decodeIfPresent(String.self, forKey: .heroImageUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .heroImageUrlCamel))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encodeIfPresent(heroImageUrl, forKey: .heroImageUrl)
    }
}

struct ActivityUser: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let username: String?
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case avatarUrl = "avatar_url"
        case avatarUrlCamel = "avatarUrl"
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try? container.decodeIfPresent(String.self, forKey: .username)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        avatarUrl = (try? container.decodeIfPresent(String.self, forKey: .avatarUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .avatarUrlCamel))
            ?? (try? container.decodeIfPresent(String.self, forKey: .image))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
    }

    var displayName: String { username ?? name ?? "Unknown" }
}
