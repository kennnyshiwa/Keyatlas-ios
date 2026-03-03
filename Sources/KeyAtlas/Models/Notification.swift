import Foundation

struct AppNotification: Codable, Identifiable, Sendable {
    let id: String
    let type: String
    let title: String?
    let message: String
    let isRead: Bool
    let projectId: String?
    let projectSlug: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, title, message
        case isRead = "is_read"
        case projectId = "project_id"
        case projectSlug = "project_slug"
        case createdAt = "created_at"
    }
}
