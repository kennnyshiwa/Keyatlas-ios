import SwiftUI

private func activityProjectSlug(_ activity: Activity) -> String? {
    guard let slug = activity.project?.slug, !slug.isEmpty else { return nil }
    // Strip any URL prefix if accidentally included
    if let url = URL(string: slug), let host = url.host, !host.isEmpty {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasPrefix("projects/") {
            return String(path.dropFirst("projects/".count))
        }
        if let last = path.split(separator: "/").last, !last.isEmpty {
            return String(last)
        }
    }
    return slug
}

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.activities.isEmpty {
                ProgressView("Loading activity…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.activities.isEmpty {
                ErrorView(message: error) { await viewModel.load() }
            } else if viewModel.activities.isEmpty {
                EmptyStateView(
                    title: "No Activity",
                    message: "Recent community activity will appear here.",
                    systemImage: "bolt.horizontal"
                )
            } else {
                List(viewModel.activities) { activity in
                    if let slug = activityProjectSlug(activity) {
                        NavigationLink {
                            ProjectDetailView(slug: slug)
                        } label: {
                            ActivityRowView(activity: activity)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    } else {
                        ActivityRowView(activity: activity)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }
}

private struct ActivityRowView: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activity.typeIcon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.typeDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if let title = activity.title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }

                if let message = activity.message, !message.isEmpty {
                    if let user = activity.user {
                        Text("\(user.displayName) \(message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 8) {
                    if let user = activity.user {
                        HStack(spacing: 4) {
                            AvatarImage(url: user.avatarUrl, size: 16)
                            Text(user.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !activity.createdAt.isEmpty {
                        Text(activity.createdAt.relativeTime)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if activityProjectSlug(activity) != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .accessibilityLabel("\(activity.typeDisplayName): \(activity.title ?? activity.message ?? "")")
    }

    private var iconColor: Color {
        switch activity.type {
        case "new_project": return .blue
        case "comment": return .green
        case "forum_thread": return .purple
        case "project_update": return .orange
        default: return .orange
        }
    }
}
