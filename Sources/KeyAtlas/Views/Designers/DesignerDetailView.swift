import SwiftUI

struct DesignerDetailView: View {
    let slug: String
    @State private var viewModel = DesignerDetailViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.designer == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.designer == nil {
                ErrorView(message: error) { await viewModel.loadDesigner(slug: slug) }
            } else if let designer = viewModel.designer {
                designerContent(designer)
            } else {
                ContentUnavailableView {
                    Label("Designer unavailable", systemImage: "paintpalette")
                } description: {
                    Text("Designer detail did not load.")
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.loadDesigner(slug: slug) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: slug) { await viewModel.loadDesigner(slug: slug) }
    }

    @ViewBuilder
    private func designerContent(_ designer: Designer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Banner
                if let bannerUrl = designer.bannerUrl {
                    CachedImage(url: bannerUrl, contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Header
                HStack(spacing: 16) {
                    AvatarImage(url: designer.logoUrl, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(designer.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        if let count = designer.projectCount {
                            Text("\(count) project\(count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Website
                if let urlStr = designer.websiteUrl, let url = URL(string: urlStr) {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Visit Website", systemImage: "globe")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Open designer website")
                }

                // Description
                if let desc = designer.description, !desc.isEmpty {
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
                } else {
                    ContentUnavailableView {
                        Label("No projects yet", systemImage: "paintpalette")
                    } description: {
                        Text("This designer doesn't have any published projects yet.")
                    }
                }
            }
            .padding()
        }
    }
}
