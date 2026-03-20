import SwiftUI

struct DesignerListView: View {
    @State private var viewModel = DesignerListViewModel()
    @State private var searchText = ""

    var filteredDesigners: [Designer] {
        if searchText.isEmpty { return viewModel.designers }
        return viewModel.designers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.designers.isEmpty {
                ProgressView("Loading designers…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.designers.isEmpty {
                ErrorView(message: error) { await viewModel.loadDesigners() }
            } else if filteredDesigners.isEmpty {
                EmptyStateView(title: "No Designers", message: "No designers found.", systemImage: "paintpalette")
            } else {
                List(filteredDesigners) { designer in
                    NavigationLink {
                        DesignerDetailView(slug: designer.slug)
                    } label: {
                        DesignerRow(designer: designer)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search designers")
        .navigationTitle("Designers")
        .refreshable { await viewModel.loadDesigners() }
        .task { await viewModel.loadDesigners() }
    }
}

struct DesignerRow: View {
    let designer: Designer

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(url: designer.logoUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(designer.name)
                    .font(.headline)
                if let count = designer.projectCount {
                    Text("\(count) project\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(designer.name)
    }
}
