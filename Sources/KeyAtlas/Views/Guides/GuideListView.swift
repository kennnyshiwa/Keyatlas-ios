import SwiftUI

struct GuideListView: View {
    @State private var viewModel = GuideViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.guides.isEmpty {
                    ProgressView("Loading guides…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error, viewModel.guides.isEmpty {
                    ErrorView(message: error) { await viewModel.loadGuides() }
                } else if viewModel.guides.isEmpty {
                    EmptyStateView(
                        title: "No Guides",
                        message: "Build guides will appear here.",
                        systemImage: "book"
                    )
                } else {
                    List(viewModel.guides) { guide in
                        NavigationLink {
                            GuideDetailView(slug: guide.slug)
                        } label: {
                            HStack(spacing: 12) {
                                CachedImage(url: guide.heroImageUrl)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(guide.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if let desc = guide.description {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    if let author = guide.author {
                                        Text("by \(author.displayName)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityLabel("Guide: \(guide.title)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Build Guides")
            .refreshable { await viewModel.loadGuides() }
            .task { await viewModel.loadGuides() }
        }
    }
}
