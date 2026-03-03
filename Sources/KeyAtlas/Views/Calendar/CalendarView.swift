import SwiftUI

struct CalendarTabView: View {
    @State private var viewModel = CalendarViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Events").tag(0)
                    Text("Deliveries").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading calendar…")
                    Spacer()
                } else if let error = viewModel.error {
                    ErrorView(message: error) { await viewModel.loadCalendar() }
                } else {
                    if selectedTab == 0 {
                        eventsView
                    } else {
                        deliveriesView
                    }
                }
            }
            .navigationTitle("Calendar")
            .refreshable { await viewModel.loadCalendar() }
            .task { await viewModel.loadCalendar() }
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(slug: project.slug)
            }
        }
    }

    // MARK: - Events

    private var eventsView: some View {
        Group {
            if viewModel.events.isEmpty {
                EmptyStateView(
                    title: "No Events",
                    message: "No calendar events found.",
                    systemImage: "calendar"
                )
            } else {
                List(viewModel.events) { event in
                    HStack(spacing: 12) {
                        VStack {
                            Text(dayFrom(event.date))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(monthFrom(event.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 50)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack(spacing: 8) {
                                if let type = event.type {
                                    Text(eventTypeLabel(type))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(eventTypeColor(type).opacity(0.15))
                                        .foregroundStyle(eventTypeColor(type))
                                        .clipShape(Capsule())
                                }
                                if let status = event.status {
                                    StatusBadge(status: status)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityLabel("\(event.title), \(event.date.readableDate)")
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Deliveries by quarter

    private var deliveriesView: some View {
        Group {
            if viewModel.deliveries.isEmpty {
                EmptyStateView(
                    title: "No Deliveries",
                    message: "No expected deliveries found.",
                    systemImage: "shippingbox"
                )
            } else {
                List {
                    ForEach(viewModel.deliveries) { quarter in
                        Section(quarter.quarter) {
                            ForEach(quarter.projects) { project in
                                NavigationLink(value: project) {
                                    HStack(spacing: 12) {
                                        CachedImage(url: project.heroImageUrl)
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(project.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            StatusBadge(status: project.status)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Helpers

    private func dayFrom(_ dateStr: String) -> String {
        guard let date = dateStr.asDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func monthFrom(_ dateStr: String) -> String {
        guard let date = dateStr.asDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    private func eventTypeLabel(_ type: String) -> String {
        switch type {
        case "gb_start": "GB Start"
        case "gb_end": "GB End"
        case "delivery": "Delivery"
        default: type
        }
    }

    private func eventTypeColor(_ type: String) -> Color {
        switch type {
        case "gb_start": .green
        case "gb_end": .red
        case "delivery": .purple
        default: .gray
        }
    }
}
