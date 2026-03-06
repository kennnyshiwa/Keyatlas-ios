import SwiftUI

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
                    message: "Follow projects and users to see your activity feed here.",
                    systemImage: "bolt.horizontal"
                )
            } else {
                List(viewModel.activities) { activity in
                    ActivityRowView(activity: activity)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
            // Icon
            Image(systemName: activity.typeIcon)
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .background(.orange.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                // Type label
                Text(activity.typeDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                // Message
                if let message = activity.message, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                // Project reference
                if let project = activity.project, let title = project.title {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.caption2)
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.blue)
                }

                // User reference
                if let user = activity.user {
                    HStack(spacing: 4) {
                        AvatarImage(url: user.avatarUrl, size: 16)
                        Text(user.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Timestamp
                if !activity.createdAt.isEmpty {
                    Text(activity.createdAt.relativeTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("\(activity.typeDisplayName): \(activity.message ?? "")")
    }
}
