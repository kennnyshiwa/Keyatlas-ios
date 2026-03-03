import SwiftUI

/// Browse all projects with sort options and infinite scroll
struct ProjectListView: View {
    @State private var viewModel = ProjectListViewModel()
    @State private var showSortPicker = false

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

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
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
