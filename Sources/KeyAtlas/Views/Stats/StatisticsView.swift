import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var viewModel = StatisticsViewModel()

    var body: some View {
        ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading statistics…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = viewModel.error {
                    ErrorView(message: error) { await viewModel.loadStatistics() }
                } else if let stats = viewModel.stats {
                    VStack(spacing: 24) {
                        // Summary cards
                        summaryCards(stats)

                        // Projects by Category pie chart
                        if let data = stats.categoryChartData, !data.isEmpty {
                            chartSection(title: "Projects by Category") {
                                Chart(data) { point in
                                    SectorMark(
                                        angle: .value("Count", point.value),
                                        innerRadius: .ratio(0.5),
                                        angularInset: 1
                                    )
                                    .foregroundStyle(by: .value("Category", point.label))
                                }
                                .frame(height: 250)
                            }
                        }

                        // Projects by Status pie chart
                        if let data = stats.statusChartData, !data.isEmpty {
                            chartSection(title: "Projects by Status") {
                                Chart(data) { point in
                                    SectorMark(
                                        angle: .value("Count", point.value),
                                        innerRadius: .ratio(0.5),
                                        angularInset: 1
                                    )
                                    .foregroundStyle(by: .value("Status", point.label))
                                }
                                .frame(height: 250)
                            }
                        }

                        // GBs per Month line chart
                        if let data = stats.groupBuysPerMonth, !data.isEmpty {
                            chartSection(title: "Group Buys per Month") {
                                Chart(data) { point in
                                    LineMark(
                                        x: .value("Month", point.label),
                                        y: .value("Count", point.value)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    AreaMark(
                                        x: .value("Month", point.label),
                                        y: .value("Count", point.value)
                                    )
                                    .foregroundStyle(.blue.opacity(0.1))
                                    .interpolationMethod(.catmullRom)
                                }
                                .frame(height: 200)
                            }
                        }

                        // Top Designers bar chart
                        if let data = stats.designerChartData, !data.isEmpty {
                            chartSection(title: "Top 10 Designers") {
                                Chart(data) { point in
                                    BarMark(
                                        x: .value("Projects", point.value),
                                        y: .value("Designer", point.label)
                                    )
                                    .foregroundStyle(.blue)
                                }
                                .frame(height: CGFloat(data.count) * 35)
                            }
                        }

                        // Top Vendors bar chart
                        if let data = stats.vendorChartData, !data.isEmpty {
                            chartSection(title: "Top 10 Vendors") {
                                Chart(data) { point in
                                    BarMark(
                                        x: .value("Projects", point.value),
                                        y: .value("Vendor", point.label)
                                    )
                                    .foregroundStyle(.green)
                                }
                                .frame(height: CGFloat(data.count) * 35)
                            }
                        }
                    }
                    .padding()
                }
            }
        .navigationTitle("Statistics")
        .refreshable { await viewModel.loadStatistics() }
        .task { await viewModel.loadStatistics() }
    }

    // MARK: - Summary cards

    private func summaryCards(_ stats: SiteStatistics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(label: "Total Projects", value: stats.totalProjects, icon: "keyboard", color: .blue)
            statCard(label: "Vendors", value: stats.totalVendors, icon: "building.2", color: .green)
            statCard(label: "Active GBs", value: stats.activeGroupBuys, icon: "cart", color: .orange)
            statCard(label: "Shipped", value: stats.shippedCount, icon: "shippingbox", color: .purple)
        }
    }

    private func statCard(label: String, value: Int?, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(value ?? 0)")
                .font(.title)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
        .accessibilityLabel("\(label): \(value ?? 0)")
    }

    // MARK: - Chart section wrapper

    private func chartSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .cardStyle()
    }
}
