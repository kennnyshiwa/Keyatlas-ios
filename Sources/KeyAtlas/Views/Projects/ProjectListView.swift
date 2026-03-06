import SwiftUI

/// Browse all projects with sort options and infinite scroll
struct ProjectListView: View {
    @State private var viewModel = ProjectListViewModel()
    @State private var showSortPicker = false

    private var followedProjects: [Project] {
        viewModel.projects.filter { $0.isFollowing == true }
    }

    private var recommendationLabel: String {
        if let first = followedProjects.first {
            return "Because you follow \(first.title)"
        }
        return "From projects you follow"
    }

    private var recommendedProjects: [Project] {
        let followedIDs = Set(followedProjects.map(\.id))
        let followedCategories = Set(followedProjects.compactMap(\.categoryId))

        return viewModel.projects
            .filter { !followedIDs.contains($0.id) }
            .filter { project in
                guard let category = project.categoryId else { return false }
                return followedCategories.contains(category)
            }
            .prefix(8)
            .map { $0 }
    }

    private var trendingProjects: [Project] {
        Array(viewModel.projects.sorted { $0.trendingScore > $1.trendingScore }.prefix(8))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let error = viewModel.error, viewModel.projects.isEmpty {
                    ErrorView(message: error) { await viewModel.refresh() }
                } else if viewModel.projects.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        title: "No Projects",
                        message: "No projects found. Pull to refresh.",
                        systemImage: "keyboard"
                    )
                } else {
                    projectList
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: Binding(
                            get: { viewModel.sortOption },
                            set: { option in Task { await viewModel.updateSort(option) } }
                        )) {
                            ForEach(ProjectSortOption.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }

                        Divider()

                        Picker("Filter", selection: Binding(
                            get: { viewModel.statusFilter },
                            set: { status in Task { await viewModel.updateFilter(status) } }
                        )) {
                            Text("All Statuses").tag(nil as ProjectStatus?)
                            ForEach(ProjectStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status as ProjectStatus?)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .accessibilityLabel("Sort and filter")
                    }
                }
            }
            .task { await viewModel.loadProjects(refresh: true) }
        }
    }

    private func laneSection(title: String, projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(projects) { project in
                        NavigationLink(value: project) {
                            CompactProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var projectList: some View {
        let hasHighlightLanes = !recommendedProjects.isEmpty || !trendingProjects.isEmpty

        return ScrollView {
            LazyVStack(spacing: 16) {
                if !recommendedProjects.isEmpty {
                    laneSection(title: recommendationLabel, projects: recommendedProjects)
                }

                if !trendingProjects.isEmpty {
                    laneSection(title: "Trending this week", projects: trendingProjects)
                }

                if hasHighlightLanes {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        Text("All Projects")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }

                ForEach(viewModel.projects) { project in
                    NavigationLink(value: project) {
                        ProjectCardView(project: project)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // Infinite scroll: load more when near the end
                        if project.id == viewModel.projects.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding()
        }
        .refreshable { await viewModel.refresh() }
        .overlay {
            if viewModel.isLoading && viewModel.projects.isEmpty {
                ProgressView("Loading projects…")
            }
        }
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(slug: project.slug)
        }
    }
}
