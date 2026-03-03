import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hasSearched && viewModel.results.isEmpty {
                    EmptyStateView(
                        title: "No Results",
                        message: "No projects found for \"\(viewModel.query)\"",
                        systemImage: "magnifyingglass"
                    )
                } else if viewModel.results.isEmpty {
                    EmptyStateView(
                        title: "Search KeyAtlas",
                        message: "Find keyboards, keycaps, and more",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.results) { project in
                                NavigationLink(value: project) {
                                    ProjectCardView(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .searchable(text: $viewModel.query, prompt: "Search projects…")
            .onChange(of: viewModel.query) { _, _ in
                viewModel.debouncedSearch()
            }
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .navigationTitle("Search")
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(slug: project.slug)
            }
        }
    }
}
