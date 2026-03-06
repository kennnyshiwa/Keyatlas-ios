import SwiftUI

struct AdminDashboardView: View {
    @State private var viewModel = AdminDashboardViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.dashboard == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if let error = viewModel.error, viewModel.dashboard == nil {
                ErrorView(message: error) { await viewModel.load() }
            } else if let dashboard = viewModel.dashboard {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        adminStatCard(label: "Total Projects", value: dashboard.totalProjects, icon: "keyboard", color: .blue)
                        adminStatCard(label: "Published", value: dashboard.publishedProjects, icon: "checkmark.circle", color: .green)
                        adminStatCard(label: "Drafts", value: dashboard.draftProjects, icon: "doc", color: .orange)
                        adminStatCard(label: "Users", value: dashboard.totalUsers, icon: "person.2", color: .purple)
                        adminStatCard(label: "Open Reports", value: dashboard.openReports, icon: "exclamationmark.triangle", color: .red)
                    }

                    if let breakdown = viewModel.dashboard?.statusBreakdown, !breakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status Breakdown")
                                .font(.headline)
                            ForEach(breakdown, id: \.status) { item in
                                HStack {
                                    Text(item.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .padding()
                        .cardStyle()
                    }

                    // Quick links
                    VStack(spacing: 0) {
                        NavigationLink {
                            AdminProjectsView()
                        } label: {
                            adminLink(title: "Manage Projects", icon: "folder")
                        }
                        Divider().padding(.leading, 48)
                        NavigationLink {
                            AdminUsersView()
                        } label: {
                            adminLink(title: "Manage Users", icon: "person.2")
                        }
                        Divider().padding(.leading, 48)
                        NavigationLink {
                            AdminReportsView()
                        } label: {
                            adminLink(title: "View Reports", icon: "exclamationmark.triangle")
                        }
                        Divider().padding(.leading, 48)
                        Divider().padding(.leading, 48)
                        NavigationLink {
                            AdminVendorsView()
                        } label: {
                            adminLink(title: "Manage Vendors", icon: "building.2")
                        }
                        Divider().padding(.leading, 48)
                        NavigationLink {
                            AdminAuditLogsView()
                        } label: {
                            adminLink(title: "Audit Logs", icon: "checklist")
                        }
                    }
                    .padding()
                    .cardStyle()
                }
                .padding()
            }
        }
        .navigationTitle("Admin")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    private func adminStatCard(label: String, value: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
    }

    private func adminLink(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

struct AdminAuditLogsView: View {
    @State private var viewModel = AdminAuditLogsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.logs.isEmpty {
                ProgressView("Loading audit logs…")
            } else if let error = viewModel.error, viewModel.logs.isEmpty {
                ErrorView(message: error) { await viewModel.load() }
            } else {
                List(viewModel.logs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(log.action)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(log.actorRole)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(log.actor.displayName ?? log.actor.username ?? log.actor.email ?? log.actorId)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(log.resource)\(log.resourceId.map { " (\($0))" } ?? "")")
                            .font(.caption)

                        Text(log.createdAt)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Audit Logs")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }
}
