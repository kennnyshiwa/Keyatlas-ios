import SwiftUI

struct AdminUsersView: View {
    @State private var viewModel = AdminUsersViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.users.isEmpty {
                ErrorView(message: error) { await viewModel.load() }
            } else if viewModel.users.isEmpty {
                EmptyStateView(title: "No Users", message: "No users found.", systemImage: "person.2")
            } else {
                List(viewModel.users) { user in
                    AdminUserRow(user: user)
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.toggleBan(user) }
                            } label: {
                                Label(
                                    user.bannedAt != nil ? "Unban" : "Ban",
                                    systemImage: user.bannedAt != nil ? "checkmark.circle" : "nosign"
                                )
                            }
                            .tint(user.bannedAt != nil ? .green : .red)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Menu {
                                ForEach(["USER", "VENDOR", "MODERATOR", "ADMIN"], id: \.self) { role in
                                    Button(role.capitalized) {
                                        Task { await viewModel.changeRole(user, to: role) }
                                    }
                                    .disabled(user.role == role)
                                }
                            } label: {
                                Label("Role", systemImage: "person.badge.key")
                            }
                            .tint(.blue)
                        }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Users")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }
}

private struct AdminUserRow: View {
    let user: AdminUser

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(url: user.image, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.username ?? user.email ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if user.bannedAt != nil {
                        Text("BANNED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.red))
                    }
                }
                HStack(spacing: 6) {
                    Text(user.role)
                        .font(.caption)
                        .foregroundStyle(roleColor(user.role))
                        .fontWeight(.semibold)
                    if let count = user.projectCount {
                        Text("• \(count) project\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "ADMIN": .red
        case "MODERATOR": .orange
        case "VENDOR": .blue
        default: .secondary
        }
    }
}
