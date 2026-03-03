import SwiftUI

struct VendorDetailView: View {
    let slug: String
    @State private var viewModel = VendorDetailViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.vendor == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.vendor == nil {
                ErrorView(message: error) { await viewModel.loadVendor(slug: slug) }
            } else if let vendor = viewModel.vendor {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack(spacing: 16) {
                            AvatarImage(url: vendor.logoUrl, size: 64)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vendor.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if let regions = vendor.regions, !regions.isEmpty {
                                    Text(regions.joined(separator: ", "))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Website
                        if let urlStr = vendor.websiteUrl, let url = URL(string: urlStr) {
                            Button {
                                openURL(url)
                            } label: {
                                Label("Visit Website", systemImage: "globe")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Open vendor website")
                        }

                        // Description
                        if let desc = vendor.description, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                        }

                        // Projects
                        if !viewModel.projects.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Projects")
                                    .font(.headline)
                                ForEach(viewModel.projects) { project in
                                    NavigationLink {
                                        ProjectDetailView(slug: project.slug)
                                    } label: {
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
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadVendor(slug: slug) }
    }
}
