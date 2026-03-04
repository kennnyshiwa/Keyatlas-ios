import Foundation

struct SiteStatistics: Codable, Hashable, Sendable {
    let totalProjects: Int?
    let totalVendors: Int?
    let activeGBs: Int?
    let shippedCount: Int?
    let projectsByCategory: [RawChartPoint]?
    let projectsByStatus: [RawChartPoint]?
    let gbsPerMonth: [RawChartPoint]?
    let topDesigners: [RawChartPoint]?
    let topVendors: [RawChartPoint]?

    var activeGroupBuys: Int? { activeGBs }
    var groupBuysPerMonth: [ChartDataPoint]? { gbsPerMonth?.map { $0.toChartPoint } }
    var statusChartData: [ChartDataPoint]? { projectsByStatus?.map { $0.toChartPoint } }
    var categoryChartData: [ChartDataPoint]? { projectsByCategory?.map { $0.toChartPoint } }
    var designerChartData: [ChartDataPoint]? { topDesigners?.map { $0.toChartPoint } }
    var vendorChartData: [ChartDataPoint]? { topVendors?.map { $0.toChartPoint } }
}

/// Raw API shape — keys vary (status/category/month/name + count)
struct RawChartPoint: Codable, Hashable, Sendable {
    // Try all known key names
    let status: String?
    let category: String?
    let month: String?
    let name: String?
    let label: String?
    let count: Double?
    let value: Double?

    var toChartPoint: ChartDataPoint {
        let lbl = label ?? status ?? category ?? month ?? name ?? "Unknown"
        let val = value ?? count ?? 0
        return ChartDataPoint(label: lbl, value: val, color: nil)
    }
}

struct ChartDataPoint: Codable, Identifiable, Hashable, Sendable {
    var id: String { label }
    let label: String
    let value: Double
    let color: String?
}
