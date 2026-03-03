import Foundation

struct SiteStatistics: Codable, Hashable, Sendable {
    let totalProjects: Int?
    let totalVendors: Int?
    let activeGroupBuys: Int?
    let shippedCount: Int?
    let projectsByCategory: [ChartDataPoint]?
    let projectsByStatus: [ChartDataPoint]?
    let groupBuysPerMonth: [ChartDataPoint]?
    let topDesigners: [ChartDataPoint]?
    let topVendors: [ChartDataPoint]?

    enum CodingKeys: String, CodingKey {
        case totalProjects = "total_projects"
        case totalVendors = "total_vendors"
        case activeGroupBuys = "active_group_buys"
        case shippedCount = "shipped_count"
        case projectsByCategory = "projects_by_category"
        case projectsByStatus = "projects_by_status"
        case groupBuysPerMonth = "group_buys_per_month"
        case topDesigners = "top_designers"
        case topVendors = "top_vendors"
    }
}

struct ChartDataPoint: Codable, Identifiable, Hashable, Sendable {
    var id: String { label }
    let label: String
    let value: Double
    let color: String?
}
