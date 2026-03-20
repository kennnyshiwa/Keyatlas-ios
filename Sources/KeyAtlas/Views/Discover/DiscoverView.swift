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
                        if !viewModel.recommendations.isEmpty {
                            projectSection(title: viewModel.recommendationLabel, icon: "person.2.wave.2", projects: viewModel.recommendations)
                        }

                        if !viewModel.trendingThisWeek.isEmpty {
                            projectSection(title: "Trending This Week", icon: "flame", projects: viewModel.trendingThisWeek)
                        }

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
                                    DesignerListView()
                                } label: {
                                    discoverLink(title: "Designers", icon: "paintpalette", subtitle: "Browse keyboard designers")
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
            CachedImage(url: project.heroImageUrl, targetSize: CGSize(width: 200, height: 130))
                .frame(width: 200, height: 130)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    compactBadge(
                        title: project.status.displayName,
                        icon: project.status.iconName,
                        foreground: Color.forStatus(project.status),
                        background: Color.forStatus(project.status).opacity(0.15)
                    )

                    Spacer(minLength: 4)

                    if project.isRecentlyUpdated {
                        compactBadge(
                            title: "Recently updated",
                            icon: nil,
                            foreground: .orange,
                            background: .orange.opacity(0.16)
                        )
                    }
                }

                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let price = project.pricing?.formattedRange {
                    Text(price)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    statItem(icon: "person.2", value: project.followCount ?? 0)
                    statItem(icon: "heart", value: project.favoriteCount ?? 0)
                    statItem(icon: "bubble.left", value: project.commentCount)
                }
                .foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .frame(width: 200)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.title), \(project.status.displayName)")
    }

    private func statItem(icon: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(value)")
                .font(.caption2)
                .fontWeight(.medium)
        }
    }

    private func compactBadge(title: String, icon: String?, foreground: Color, background: Color) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(foreground)
        .frame(minHeight: 26)
        .frame(width: 72)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(background)
        .clipShape(Capsule())
    }
}
