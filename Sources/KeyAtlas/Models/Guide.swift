import Foundation

struct Guide: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let difficulty: String?
    let content: String?
    let heroImage: String?
    let author: UserSummary?
    let createdAt: String
    let updatedAt: String?
}
