import Foundation

// MARK: - Admin Models

struct AdminVendor: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let website: String?
    let region: String?
    let logo: String?
    let projectCount: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, website, region, logo
        case projectCount = "project_count"
        case createdAt = "created_at"
    }
}

struct AdminDashboard: Codable, Hashable, Sendable {
    let totalProjects: Int
    let publishedProjects: Int
    let draftProjects: Int
    let totalUsers: Int
    let openReports: Int
    let statusBreakdown: [AdminStatusCount]?
}

struct AdminStatusCount: Codable, Hashable, Sendable {
    let status: String
    let count: Int
}

struct AdminProject: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let status: String
    let published: Bool
    let heroImage: String?
    let createdAt: String
    let updatedAt: String
    let creator: AdminProjectCreator?
}

struct AdminProjectCreator: Codable, Hashable, Sendable {
    let id: String
    let username: String?
}

struct AdminUser: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let username: String?
    let email: String?
    let role: String
    let bannedAt: String?
    let banReason: String?
    let image: String?
    let createdAt: String
    let lastSeenAt: String?
    let projectCount: Int?
}

struct AdminReport: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let reason: String
    let status: String
    let createdAt: String
    let resolvedAt: String?
    let resolutionNote: String?
    let project: AdminReportProject?
    let reporter: AdminReportUser?
}

struct AdminReportProject: Codable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
}

struct AdminReportUser: Codable, Hashable, Sendable {
    let id: String
    let username: String?
}

struct AdminAuditActor: Codable, Hashable, Sendable {
    let id: String
    let username: String?
    let displayName: String?
    let email: String?
}

struct AdminAuditLog: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let actorId: String
    let actorRole: String
    let action: String
    let resource: String
    let resourceId: String?
    let targetId: String?
    let metadata: String?
    let ipAddress: String?
    let userAgent: String?
    let createdAt: String
    let actor: AdminAuditActor
}

// MARK: - ViewModels

@Observable
final class AdminDashboardViewModel: @unchecked Sendable {
    var dashboard: AdminDashboard?
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: APIDataResponse<AdminDashboard> = try await api.request(
                path: "/api/v1/admin/dashboard", authenticated: true
            )
            await MainActor.run { self.dashboard = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

@Observable
final class AdminProjectsViewModel: @unchecked Sendable {
    var projects: [AdminProject] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<AdminProject> = try await api.request(
                path: "/api/v1/admin/projects", authenticated: true
            )
            await MainActor.run { self.projects = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func togglePublish(_ project: AdminProject) async {
        do {
            struct UpdateBody: Codable, Sendable { let published: Bool }
            let _: APIDataResponse<AdminProject> = try await api.request(
                .patch,
                path: "/api/v1/admin/projects/\(project.id)",
                body: UpdateBody(published: !project.published),
                authenticated: true
            )
            await load()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func deleteProject(_ project: AdminProject) async {
        do {
            try await api.requestVoid(.delete, path: "/api/v1/admin/projects/\(project.id)")
            await load()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

@Observable
final class AdminUsersViewModel: @unchecked Sendable {
    var users: [AdminUser] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<AdminUser> = try await api.request(
                path: "/api/v1/admin/users", authenticated: true
            )
            await MainActor.run { self.users = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func toggleBan(_ user: AdminUser) async {
        do {
            struct UpdateBody: Codable, Sendable { let banned: Bool }
            let isBanned = user.bannedAt != nil
            let _: APIDataResponse<EmptyResponse> = try await api.request(
                .patch,
                path: "/api/v1/admin/users/\(user.id)",
                body: UpdateBody(banned: !isBanned),
                authenticated: true
            )
            await load()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func changeRole(_ user: AdminUser, to role: String) async {
        do {
            struct UpdateBody: Codable, Sendable { let role: String }
            let _: APIDataResponse<EmptyResponse> = try await api.request(
                .patch,
                path: "/api/v1/admin/users/\(user.id)",
                body: UpdateBody(role: role),
                authenticated: true
            )
            await load()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

@Observable
final class AdminAuditLogsViewModel: @unchecked Sendable {
    var logs: [AdminAuditLog] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<AdminAuditLog> = try await api.request(
                path: "/api/v1/admin/audit-logs", authenticated: true
            )
            await MainActor.run { self.logs = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

@Observable
final class AdminVendorsViewModel: @unchecked Sendable {
    var vendors: [AdminVendor] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<AdminVendor> = try await api.request(
                path: "/api/v1/admin/vendors", authenticated: true
            )
            await MainActor.run { self.vendors = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func createVendor(name: String, slug: String, website: String?, region: String?) async throws {
        struct CreateBody: Codable, Sendable {
            let name: String
            let slug: String
            let website: String?
            let region: String?
        }
        let _: APIDataResponse<AdminVendor> = try await api.request(
            .post,
            path: "/api/v1/admin/vendors",
            body: CreateBody(name: name, slug: slug, website: website?.isEmpty == true ? nil : website, region: region?.isEmpty == true ? nil : region),
            authenticated: true
        )
        await load()
    }

    func updateVendor(_ vendor: AdminVendor, name: String, slug: String, website: String?, region: String?) async throws {
        struct UpdateBody: Codable, Sendable {
            let name: String
            let slug: String
            let website: String?
            let region: String?
        }
        let _: APIDataResponse<AdminVendor> = try await api.request(
            .patch,
            path: "/api/v1/admin/vendors/\(vendor.id)",
            body: UpdateBody(name: name, slug: slug, website: website?.isEmpty == true ? nil : website, region: region?.isEmpty == true ? nil : region),
            authenticated: true
        )
        await load()
    }

    func deleteVendor(_ vendor: AdminVendor) async {
        do {
            try await api.requestVoid(.delete, path: "/api/v1/admin/vendors/\(vendor.id)")
            await load()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}

@Observable
final class AdminReportsViewModel: @unchecked Sendable {
    var reports: [AdminReport] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    func load() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: PaginatedResponse<AdminReport> = try await api.request(
                path: "/api/v1/admin/reports", authenticated: true
            )
            await MainActor.run { self.reports = response.data }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func resolve(_ report: AdminReport) async {
        do {
            struct UpdateBody: Codable, Sendable { let status: String }
            let _: APIDataResponse<EmptyResponse> = try await api.request(
                .patch,
                path: "/api/v1/admin/reports/\(report.id)",
                body: UpdateBody(status: "RESOLVED"),
                authenticated: true
            )
            await load()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    func dismiss(_ report: AdminReport) async {
        do {
            struct UpdateBody: Codable, Sendable { let status: String }
            let _: APIDataResponse<EmptyResponse> = try await api.request(
                .patch,
                path: "/api/v1/admin/reports/\(report.id)",
                body: UpdateBody(status: "NON_ISSUE"),
                authenticated: true
            )
            await load()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
