import Foundation

struct AppNotification: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let type: String
    let title: String
    let message: String
    let link: String?
    let createdAt: String
    let readAt: String?
    let metadata: [String: String]?

    var isRead: Bool { readAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, type, title, message, link, metadata
        case readAt
        case createdAt

        // Legacy keys
        case isRead = "is_read"
        case createdAtLegacy = "created_at"
        case projectId = "project_id"
        case projectSlug = "project_slug"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        title = (try? container.decode(String.self, forKey: .title)) ?? "Notification"
        message = try container.decode(String.self, forKey: .message)
        link = try? container.decodeIfPresent(String.self, forKey: .link)

        let created = (try? container.decode(String.self, forKey: .createdAt))
            ?? (try? container.decode(String.self, forKey: .createdAtLegacy))
            ?? ""
        createdAt = created

        let decodedReadAt = try? container.decodeIfPresent(String.self, forKey: .readAt)
        if let decodedReadAt {
            readAt = decodedReadAt
        } else {
            let legacyRead = (try? container.decode(Bool.self, forKey: .isRead)) ?? false
            readAt = legacyRead ? createdAt : nil
        }

        if let parsed = try? container.decodeIfPresent([String: String].self, forKey: .metadata) {
            metadata = parsed
        } else {
            var legacy: [String: String] = [:]
            if let projectId = try container.decodeIfPresent(String.self, forKey: .projectId) {
                legacy["projectId"] = projectId
            }
            if let projectSlug = try container.decodeIfPresent(String.self, forKey: .projectSlug) {
                legacy["projectSlug"] = projectSlug
            }
            metadata = legacy.isEmpty ? nil : legacy
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(link, forKey: .link)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(readAt, forKey: .readAt)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}
