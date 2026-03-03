import SwiftUI

struct ThreadListView: View {
    let category: ForumCategory
    @State private var viewModel = ThreadListViewModel()
    @State private var showNewThread = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.threads.isEmpty {
                ProgressView("Loading threads…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.threads.isEmpty {
                ErrorView(message: error) { await viewModel.loadThreads(categoryId: category.id) }
            } else if viewModel.threads.isEmpty {
                EmptyStateView(
                    title: "No Threads",
                    message: "Start the first discussion!",
                    systemImage: "text.bubble"
                )
            } else {
                List(viewModel.threads) { thread in
                    NavigationLink {
                        ThreadDetailView(threadId: thread.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if thread.isPinned == true {
                                    Image(systemName: "pin.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                Text(thread.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if thread.isLocked == true {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            HStack {
                                if let author = thread.author {
                                    Text(author.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let posts = thread.postCount {
                                    Label("\(posts)", systemImage: "message")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Text(thread.createdAt.relativeTime)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewThread = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New thread")
            }
        }
        .sheet(isPresented: $showNewThread) {
            NewThreadView(categoryId: category.id) {
                Task { await viewModel.loadThreads(categoryId: category.id) }
            }
        }
        .refreshable { await viewModel.loadThreads(categoryId: category.id) }
        .task { await viewModel.loadThreads(categoryId: category.id) }
    }
}

/// Create new thread sheet
struct NewThreadView: View {
    let categoryId: String
    let onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var isPosting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Thread Title") {
                    TextField("Title", text: $title)
                        .accessibilityLabel("Thread title")
                }
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .accessibilityLabel("Thread content")
                }
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task { await createThread() }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isPosting)
                }
            }
        }
    }

    private func createThread() async {
        isPosting = true
        defer { isPosting = false }

        struct NewThreadBody: Codable, Hashable, Sendable {
            let title: String
            let content: String
            let categoryId: String

            enum CodingKeys: String, CodingKey {
                case title, content
                case categoryId = "category_id"
            }
        }

        do {
            try await APIClient.shared.requestVoid(
                .post,
                path: "/api/v1/forums/threads",
                body: NewThreadBody(title: title, content: content, categoryId: categoryId)
            )
            onCreated()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
