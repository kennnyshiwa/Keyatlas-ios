import Foundation

struct CalendarEvent: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let slug: String?
    let type: String? // "gb_start", "gb_end", "delivery"
    let date: String
    let status: ProjectStatus?
    let heroImageUrl: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id, title, slug, type, date, status, category
        case heroImageUrl = "hero_image_url"
    }
}

struct CalendarResponse: Codable, Sendable {
    let events: [CalendarEvent]?
    let deliveries: [DeliveryQuarter]?
}

struct DeliveryQuarter: Codable, Identifiable, Sendable {
    var id: String { quarter }
    let quarter: String // e.g. "Q1 2026"
    let projects: [Project]
}
