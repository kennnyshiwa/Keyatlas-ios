import SwiftUI

struct ThreadDetailView: View {
    let threadId: String
    @State private var viewModel = ThreadDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.thread == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.thread == nil {
                ErrorView(message: error) { await viewModel.loadThread(id: threadId) }
            } else if let thread = viewModel.thread {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Thread header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(thread.title)
                                .font(.title2)
                                .fontWeight(.bold)

                            HStack {
                                if let author = thread.author {
                                    AvatarImage(url: author.effectiveAvatarUrl, size: 24)
                                    Text(author.displayName)
                                        .font(.subheadline)
                                }
                                Spacer()
                                Text(thread.createdAt.relativeTime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let content = thread.content {
                                Text(content)
                                    .font(.body)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .cardStyle()

                        // Posts
                        if let posts = thread.posts {
                            ForEach(posts) { post in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        AvatarImage(url: post.author?.effectiveAvatarUrl, size: 28)
                                        Text(post.author?.displayName ?? "Anonymous")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(post.createdAt.relativeTime)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Text(post.content)
                                        .font(.body)
                                }
                                .padding()
                                .cardStyle()
                            }
                        }

                        // Reply input
                        if thread.isLocked != true {
                            VStack(spacing: 8) {
                                TextEditor(text: $viewModel.replyText)
                                    .frame(minHeight: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.quaternary)
                                    )
                                    .accessibilityLabel("Reply text")

                                Button {
                                    Task { await viewModel.postReply() }
                                } label: {
                                    HStack {
                                        if viewModel.isPosting {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                        Text("Reply")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPosting)
                                .accessibilityLabel("Post reply")
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadThread(id: threadId) }
    }
}
