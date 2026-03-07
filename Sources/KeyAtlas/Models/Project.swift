import Foundation

/// Project status in the KeyAtlas lifecycle
enum ProjectStatus: String, Codable, CaseIterable, Sendable {
    case interestCheck = "INTEREST_CHECK"
    case groupBuy = "GROUP_BUY"
    case production = "PRODUCTION"
    case shipping = "SHIPPING"
    case extras = "EXTRAS"
    case completed = "COMPLETED"
    case archived = "ARCHIVED"
    case cancelled = "CANCELLED"
    case inStock = "IN_STOCK"

    var displayName: String {
        switch self {
        case .interestCheck: "Interest Check"
        case .groupBuy: "Group Buy"
        case .production: "Production"
        case .shipping: "Shipping"
        case .extras: "Extras"
        case .completed: "Completed"
        case .archived: "Archived"
        case .cancelled: "Cancelled"
        case .inStock: "In Stock"
        }
    }

    var iconName: String {
        switch self {
        case .interestCheck: "lightbulb"
        case .groupBuy: "cart"
        case .production: "hammer"
        case .shipping: "shippingbox"
        case .extras: "bag"
        case .completed: "checkmark.circle"
        case .archived: "archivebox"
        case .cancelled: "xmark.circle"
        case .inStock: "shippingbox.fill"
        }
    }

    var colorName: String {
        switch self {
        case .interestCheck: "blue"
        case .groupBuy: "green"
        case .production: "orange"
        case .shipping: "purple"
        case .extras: "indigo"
        case .completed: "gray"
        case .archived: "gray"
        case .cancelled: "red"
        case .inStock: "teal"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ProjectStatus(rawValue: raw) ?? .interestCheck
    }
}

/// Category for a project (keycaps, switches, keyboards, etc.)
struct ProjectCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let projectCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case projectCount = "project_count"
    }

    /// Category labels matching the backend enum
    private static let labels: [String: String] = [
        "KEYBOARDS": "Keyboards",
        "KEYCAPS": "Keycaps",
        "SWITCHES": "Switches",
        "DESKMATS": "Deskmats",
        "ARTISANS": "Artisans",
        "ACCESSORIES": "Accessories",
    ]

    init(from decoder: Decoder) throws {
        // Try decoding as a plain string first (project API returns enum string)
        if let container = try? decoder.singleValueContainer(),
           let raw = try? container.decode(String.self) {
            id = raw
            name = Self.labels[raw] ?? raw.capitalized
            slug = raw.lowercased()
            description = nil
            projectCount = nil
            return
        }
        // Otherwise decode as object (categories list API)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        projectCount = try container.decodeIfPresent(Int.self, forKey: .projectCount)
    }
}

/// Pricing info for a project
struct ProjectPricing: Codable, Hashable, Sendable {
    let minPrice: Int? // cents
    let maxPrice: Int? // cents
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case minPrice = "min_price"
        case maxPrice = "max_price"
        case currency
    }

    var formattedRange: String? {
        guard let min = minPrice else { return nil }
        let curr = currency ?? "USD"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = curr

        let minStr = formatter.string(from: NSNumber(value: Double(min) / 100.0)) ?? "$\(min/100)"
        if let max = maxPrice, max != min {
            let maxStr = formatter.string(from: NSNumber(value: Double(max) / 100.0)) ?? "$\(max/100)"
            return "\(minStr) – \(maxStr)"
        }
        return minStr
    }
}

/// Timeline entry for a project
struct TimelineEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let description: String?
    let date: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, date
        case createdAt = "created_at"
    }
}

/// Gallery image
struct GalleryImage: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let url: String
    let caption: String?
    let position: Int?
}

/// Project vendor association
struct ProjectVendor: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let vendor: Vendor?
    let url: String?
    let region: String?
}

/// Project update
struct ProjectUpdate: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case createdAt = "created_at"
    }
}

/// Comment on a project
struct Comment: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let content: String
    let createdAt: String
    let updatedAt: String?
    let author: UserSummary?

    enum CodingKeys: String, CodingKey {
        case id, content, author
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Sound test entry
struct SoundTest: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String?
    let url: String
    let platform: String?
}

/// The main Project model
struct Project: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let description: String?
    let status: ProjectStatus
    let heroImageUrl: String?
    let category: ProjectCategory?
    let categoryId: String?
    let profile: String?
    let designer: UserSummary?
    let pricing: ProjectPricing?
    let vendors: [ProjectVendor]?
    let gallery: [GalleryImage]?
    let timeline: [TimelineEntry]?
    let updates: [ProjectUpdate]?
    let comments: [Comment]?
    let tags: [String]?
    let links: [ProjectLink]?
    let soundTests: [SoundTest]?
    let estimatedDelivery: String?
    let gbStartDate: String?
    let gbEndDate: String?
    let followCount: Int?
    let favoriteCount: Int?
    let isFollowing: Bool?
    let isFavorited: Bool?
    let isFeatured: Bool?
    let isInCollection: Bool?
    let published: Bool?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, status, category, tags, links, vendors, gallery, timeline, updates, comments, designer, pricing, published, profile
        case soundTests = "sound_tests"
        case heroImageUrl = "hero_image_url"
        case categoryId = "category_id"
        case estimatedDelivery = "estimated_delivery"
        case gbStartDate = "gb_start_date"
        case gbEndDate = "gb_end_date"
        case followCount = "follow_count"
        case favoriteCount = "favorite_count"
        case isFollowing = "is_following"
        case isFavorited = "is_favorited"
        case isFeatured = "is_featured"
        case isInCollection = "is_in_collection"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ProjectLink: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let url: String
}

/// Paginated response wrapper
struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: [T]
    let total: Int?
    let page: Int?
    let pageSize: Int?
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case data, total, page
        case pageSize = "page_size"
        case hasMore = "has_more"
    }
}
