import SwiftUI

struct VendorListView: View {
    @State private var viewModel = VendorListViewModel()
    @State private var searchText = ""

    var filteredVendors: [Vendor] {
        if searchText.isEmpty { return viewModel.vendors }
        return viewModel.vendors.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.vendors.isEmpty {
                    ProgressView("Loading vendors…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error, viewModel.vendors.isEmpty {
                    ErrorView(message: error) { await viewModel.loadVendors() }
                } else if filteredVendors.isEmpty {
                    EmptyStateView(title: "No Vendors", message: "No vendors found.", systemImage: "building.2")
                } else {
                    List(filteredVendors) { vendor in
                        NavigationLink(value: vendor) {
                            VendorRow(vendor: vendor)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search vendors")
            .navigationTitle("Vendors")
            .navigationDestination(for: Vendor.self) { vendor in
                VendorDetailView(slug: vendor.slug)
            }
            .refreshable { await viewModel.loadVendors() }
            .task { await viewModel.loadVendors() }
        }
    }
}

struct VendorRow: View {
    let vendor: Vendor

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(url: vendor.logoUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(vendor.name)
                    .font(.headline)
                if let regions = vendor.regions, !regions.isEmpty {
                    Text(regions.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let count = vendor.projectCount {
                    Text("\(count) project\(count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(vendor.name)
    }
}
