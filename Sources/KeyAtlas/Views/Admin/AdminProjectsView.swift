import SwiftUI

struct AdminProjectsView: View {
    @State private var viewModel = AdminProjectsViewModel()
    @State private var showDeleteConfirm = false
    @State private var projectToDelete: AdminProject?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.projects.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.projects.isEmpty {
                ErrorView(message: error) { await viewModel.load() }
            } else if viewModel.projects.isEmpty {
                EmptyStateView(title: "No Projects", message: "No projects found.", systemImage: "folder")
            } else {
                List(viewModel.projects) { project in
                    AdminProjectRow(project: project)
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.togglePublish(project) }
                            } label: {
                                Label(
                                    project.published ? "Unpublish" : "Publish",
                                    systemImage: project.published ? "eye.slash" : "eye"
                                )
                            }
                            .tint(project.published ? .orange : .green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                projectToDelete = project
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Projects")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .alert("Delete Project?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    Task { await viewModel.deleteProject(project) }
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

private struct AdminProjectRow: View {
    let project: AdminProject

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(url: project.heroImage)
                .frame(width: 60, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(project.status.replacingOccurrences(of: "_", with: " "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(project.published ? .green : .orange)
                        .frame(width: 6, height: 6)
                    Text(project.published ? "Published" : "Draft")
                        .font(.caption2)
                        .foregroundStyle(project.published ? .green : .orange)
                }
                if let creator = project.creator {
                    Text("by \(creator.username ?? "unknown")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
