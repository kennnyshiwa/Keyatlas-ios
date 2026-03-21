import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSearching {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hasSearched && !viewModel.hasAnyResults {
                    EmptyStateView(
                        title: "No Results",
                        message: "Nothing found for \"\(viewModel.query)\"",
                        systemImage: "magnifyingglass"
                    )
                } else if !viewModel.hasSearched {
                    EmptyStateView(
                        title: "Search KeyAtlas",
                        message: "Find projects, vendors, and designers",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            // Designers
                            if !viewModel.designerResults.isEmpty {
                                searchSection(title: "Designers", icon: "paintpalette") {
                                    ForEach(viewModel.designerResults) { designer in
                                        NavigationLink {
                                            DesignerDetailView(slug: designer.slug)
                                        } label: {
                                            DesignerRow(designer: designer)
                                        }
                                    }
                                }
                            }

                            // Vendors
                            if !viewModel.vendorResults.isEmpty {
                                searchSection(title: "Vendors", icon: "building.2") {
                                    ForEach(viewModel.vendorResults) { vendor in
                                        NavigationLink {
                                            VendorDetailView(slug: vendor.slug)
                                        } label: {
                                            VendorRow(vendor: vendor)
                                        }
                                    }
                                }
                            }

                            // Projects
                            if !viewModel.results.isEmpty {
                                searchSection(title: "Projects", icon: "keyboard") {
                                    ForEach(viewModel.results) { project in
                                        NavigationLink(value: project) {
                                            ProjectCardView(project: project)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .searchable(text: $viewModel.query, prompt: "Search projects, vendors, designers…")
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

    @ViewBuilder
    private func searchSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
    }
}
