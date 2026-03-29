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
    var id: String
    var title: String

    /// Title with HTML entities decoded for display (e.g. &#12304; → 【)
    var displayTitle: String { title.decodingHTMLEntities }
    var slug: String
    var description: String?
    var status: ProjectStatus
    var heroImageUrl: String?
    var category: ProjectCategory?
    var categoryId: String?
    var profile: String?
    var designer: UserSummary?
    var designerProfile: DesignerProfile?
    var pricing: ProjectPricing?
    var vendors: [ProjectVendor]?
    var gallery: [GalleryImage]?
    var timeline: [TimelineEntry]?
    var updates: [ProjectUpdate]?
    var comments: [Comment]?
    var tags: [String]?
    var links: [ProjectLink]?
    var soundTests: [SoundTest]?
    var estimatedDelivery: String?
    var gbStartDate: String?
    var gbEndDate: String?
    var followCount: Int?
    var favoriteCount: Int?
    var apiCommentCount: Int?
    var isFollowing: Bool?
    var isFavorited: Bool?
    var isFeatured: Bool?
    var isInCollection: Bool?
    var published: Bool?
    var createdAt: String
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, status, category, tags, links, vendors, gallery, timeline, updates, comments, designer, pricing, published, profile
        case designerProfile = "designer_profile"
        case soundTests = "sound_tests"
        case heroImageUrl = "hero_image_url"
        case categoryId = "category_id"
        case estimatedDelivery = "estimated_delivery"
        case gbStartDate = "gb_start_date"
        case gbEndDate = "gb_end_date"
        case followCount = "follow_count"
        case favoriteCount = "favorite_count"
        case apiCommentCount = "comment_count"
        case isFollowing = "is_following"
        case isFavorited = "is_favorited"
        case isFeatured = "is_featured"
        case isInCollection = "is_in_collection"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Memberwise initializer (used by VendorViewModel and other manual construction)
    init(
        id: String, title: String, slug: String, description: String? = nil,
        status: ProjectStatus, heroImageUrl: String? = nil, category: ProjectCategory? = nil,
        categoryId: String? = nil, profile: String? = nil, designer: UserSummary? = nil,
        designerProfile: DesignerProfile? = nil, pricing: ProjectPricing? = nil,
        vendors: [ProjectVendor]? = nil, gallery: [GalleryImage]? = nil,
        timeline: [TimelineEntry]? = nil, updates: [ProjectUpdate]? = nil,
        comments: [Comment]? = nil, tags: [String]? = nil, links: [ProjectLink]? = nil,
        soundTests: [SoundTest]? = nil, estimatedDelivery: String? = nil,
        gbStartDate: String? = nil, gbEndDate: String? = nil, followCount: Int? = nil,
        favoriteCount: Int? = nil, apiCommentCount: Int? = nil, isFollowing: Bool? = nil,
        isFavorited: Bool? = nil, isFeatured: Bool? = nil, isInCollection: Bool? = nil,
        published: Bool? = nil, createdAt: String = "", updatedAt: String? = nil
    ) {
        self.id = id; self.title = title; self.slug = slug; self.description = description
        self.status = status; self.heroImageUrl = heroImageUrl; self.category = category
        self.categoryId = categoryId; self.profile = profile; self.designer = designer
        self.designerProfile = designerProfile; self.pricing = pricing; self.vendors = vendors
        self.gallery = gallery; self.timeline = timeline; self.updates = updates
        self.comments = comments; self.tags = tags; self.links = links
        self.soundTests = soundTests; self.estimatedDelivery = estimatedDelivery
        self.gbStartDate = gbStartDate; self.gbEndDate = gbEndDate
        self.followCount = followCount; self.favoriteCount = favoriteCount
        self.apiCommentCount = apiCommentCount; self.isFollowing = isFollowing
        self.isFavorited = isFavorited; self.isFeatured = isFeatured
        self.isInCollection = isInCollection; self.published = published
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    /// Extra keys returned by search API that differ from detail API
    private enum SearchKeys: String, CodingKey {
        case heroImage
        case designer
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        slug = try container.decode(String.self, forKey: .slug)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decode(ProjectStatus.self, forKey: .status)
        category = try container.decodeIfPresent(ProjectCategory.self, forKey: .category)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        profile = try container.decodeIfPresent(String.self, forKey: .profile)
        designerProfile = try container.decodeIfPresent(DesignerProfile.self, forKey: .designerProfile)
        pricing = try container.decodeIfPresent(ProjectPricing.self, forKey: .pricing)
        vendors = try container.decodeIfPresent([ProjectVendor].self, forKey: .vendors)
        gallery = try container.decodeIfPresent([GalleryImage].self, forKey: .gallery)
        timeline = try container.decodeIfPresent([TimelineEntry].self, forKey: .timeline)
        updates = try container.decodeIfPresent([ProjectUpdate].self, forKey: .updates)
        comments = try container.decodeIfPresent([Comment].self, forKey: .comments)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        links = try container.decodeIfPresent([ProjectLink].self, forKey: .links)
        soundTests = try container.decodeIfPresent([SoundTest].self, forKey: .soundTests)
        estimatedDelivery = try container.decodeIfPresent(String.self, forKey: .estimatedDelivery)
        gbStartDate = try container.decodeIfPresent(String.self, forKey: .gbStartDate)
        gbEndDate = try container.decodeIfPresent(String.self, forKey: .gbEndDate)
        followCount = try container.decodeIfPresent(Int.self, forKey: .followCount)
        favoriteCount = try container.decodeIfPresent(Int.self, forKey: .favoriteCount)
        apiCommentCount = try container.decodeIfPresent(Int.self, forKey: .apiCommentCount)
        isFollowing = try container.decodeIfPresent(Bool.self, forKey: .isFollowing)
        isFavorited = try container.decodeIfPresent(Bool.self, forKey: .isFavorited)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured)
        isInCollection = try container.decodeIfPresent(Bool.self, forKey: .isInCollection)
        published = try container.decodeIfPresent(Bool.self, forKey: .published)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // heroImageUrl: try "hero_image_url" first, then fall back to "heroImage" (search API)
        if let url = try container.decodeIfPresent(String.self, forKey: .heroImageUrl) {
            heroImageUrl = url
        } else {
            let searchContainer = try decoder.container(keyedBy: SearchKeys.self)
            heroImageUrl = try searchContainer.decodeIfPresent(String.self, forKey: .heroImage)
        }

        // designer: try as UserSummary object first, then as plain string (search API)
        if let obj = try? container.decodeIfPresent(UserSummary.self, forKey: .designer) {
            designer = obj
        } else if let name = try? container.decodeIfPresent(String.self, forKey: .designer), !name.isEmpty {
            designer = UserSummary(id: "", username: name, name: name, avatarUrl: nil, image: nil, role: nil)
        } else {
            designer = nil
        }

        // createdAt: also try camelCase key from search API
        if createdAt.isEmpty {
            let searchContainer = try decoder.container(keyedBy: SearchKeys.self)
            createdAt = try searchContainer.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        }
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
