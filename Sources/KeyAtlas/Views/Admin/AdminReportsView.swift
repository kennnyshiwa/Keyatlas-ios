import SwiftUI

struct AdminReportsView: View {
    @State private var viewModel = AdminReportsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.reports.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.reports.isEmpty {
                ErrorView(message: error) { await viewModel.load() }
            } else if viewModel.reports.isEmpty {
                EmptyStateView(title: "No Reports", message: "No open reports.", systemImage: "checkmark.shield")
            } else {
                List(viewModel.reports) { report in
                    AdminReportRow(report: report)
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.resolve(report) }
                            } label: {
                                Label("Resolve", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                Task { await viewModel.dismiss(report) }
                            } label: {
                                Label("Dismiss", systemImage: "xmark.circle")
                            }
                            .tint(.orange)
                        }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Reports")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }
}

private struct AdminReportRow: View {
    let report: AdminReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let project = report.project {
                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Text(report.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack(spacing: 8) {
                Text(report.status)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusColor(report.status))
                if let reporter = report.reporter {
                    Text("by \(reporter.username ?? "unknown")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "OPEN": .red
        case "RESOLVED": .green
        case "NON_ISSUE": .orange
        default: .secondary
        }
    }
}
