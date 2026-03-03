import SwiftUI

struct ForumListView: View {
    @State private var viewModel = ForumViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    ProgressView("Loading forums…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error, viewModel.categories.isEmpty {
                    ErrorView(message: error) { await viewModel.loadCategories() }
                } else if viewModel.categories.isEmpty {
                    EmptyStateView(
                        title: "No Forums",
                        message: "Forum categories will appear here.",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                } else {
                    List(viewModel.categories) { category in
                        NavigationLink {
                            ThreadListView(category: category)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.name)
                                    .font(.headline)
                                if let desc = category.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 12) {
                                    if let threads = category.threadCount {
                                        Label("\(threads) threads", systemImage: "text.bubble")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    if let posts = category.postCount {
                                        Label("\(posts) posts", systemImage: "message")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityLabel("Forum category: \(category.name)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Forums")
            .refreshable { await viewModel.loadCategories() }
            .task { await viewModel.loadCategories() }
        }
    }
}
