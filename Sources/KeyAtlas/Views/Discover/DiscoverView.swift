import SwiftUI

/// Main discover tab with sections for IC, GB, Ending Soon, New This Week
struct DiscoverView: View {
    @State private var viewModel = DiscoverViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.groupBuys.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = viewModel.error, viewModel.groupBuys.isEmpty {
                    ErrorView(message: error) { await viewModel.loadAll() }
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        // New This Week
                        if !viewModel.newThisWeek.isEmpty {
                            projectSection(title: "New This Week", icon: "sparkles", projects: viewModel.newThisWeek)
                        }

                        // Active Group Buys
                        if !viewModel.groupBuys.isEmpty {
                            projectSection(title: "Group Buys", icon: "cart", projects: viewModel.groupBuys)
                        }

                        // Ending Soon
                        if !viewModel.endingSoon.isEmpty {
                            projectSection(title: "Ending Soon", icon: "clock.badge.exclamationmark", projects: viewModel.endingSoon)
                        }

                        // Interest Checks
                        if !viewModel.interestChecks.isEmpty {
                            projectSection(title: "Interest Checks", icon: "lightbulb", projects: viewModel.interestChecks)
                        }

                        Divider().padding(.horizontal)

                        // Explore More
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Explore More", systemImage: "compass")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                NavigationLink {
                                    VendorListView()
                                } label: {
                                    discoverLink(title: "Vendors", icon: "building.2", subtitle: "Browse keyboard vendors")
                                }

                                Divider().padding(.leading, 56)

                                NavigationLink {
                                    GuideListView()
                                } label: {
                                    discoverLink(title: "Guides", icon: "book", subtitle: "Build guides & tutorials")
                                }

                                Divider().padding(.leading, 56)

                                NavigationLink {
                                    StatisticsView()
                                } label: {
                                    discoverLink(title: "Statistics", icon: "chart.bar", subtitle: "Community stats & trends")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .refreshable { await viewModel.loadAll() }
            .navigationTitle("Discover")
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(slug: project.slug)
            }
            .task { await viewModel.loadAll() }
        }
    }

    private func discoverLink(title: String, icon: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
    }

    private func projectSection(title: String, icon: String, projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(projects) { project in
                        NavigationLink(value: project) {
                            CompactProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Compact horizontal card for discover sections
struct CompactProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CachedImage(url: project.heroImageUrl)
                .frame(width: 200, height: 130)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                StatusBadge(status: project.status)

                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let price = project.pricing?.formattedRange {
                    Text(price)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
        .frame(width: 200)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.title), \(project.status.displayName)")
    }
}
