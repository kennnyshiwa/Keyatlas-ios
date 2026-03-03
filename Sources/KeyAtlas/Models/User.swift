import Foundation

/// Lightweight user reference used in project/comment payloads
struct UserSummary: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let username: String?
    let name: String?
    let avatarUrl: String?
    let image: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name, image
        case avatarUrl = "avatar_url"
    }

    var displayName: String {
        username ?? name ?? "Unknown"
    }

    var effectiveAvatarUrl: String? {
        avatarUrl ?? image
    }
}

/// Full user profile
struct UserProfile: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let username: String?
    let name: String?
    let email: String?
    let bio: String?
    let avatarUrl: String?
    let image: String?
    let projects: [Project]?
    let followerCount: Int?
    let followingCount: Int?
    let isFollowing: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name, email, bio, image, projects
        case avatarUrl = "avatar_url"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case isFollowing = "is_following"
        case createdAt = "created_at"
    }

    var displayName: String {
        username ?? name ?? "Unknown"
    }

    var effectiveAvatarUrl: String? {
        avatarUrl ?? image
    }
}

/// Auth session response
struct AuthSession: Codable, Hashable, Sendable {
    let user: UserSummary?
    let accessToken: String?
    let expires: String?

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case expires
    }
}

/// Login/signup request
struct AuthCredentials: Codable, Hashable, Sendable {
    let email: String
    let password: String
    let username: String?
}
