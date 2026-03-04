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

    @ViewBuilder
    private var eventsView: some View {
        if viewModel.events.isEmpty {
            EmptyStateView(
                title: "No Events",
                message: "No calendar events found.",
                systemImage: "calendar"
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button {
                            viewModel.moveMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Spacer()
                        Text(viewModel.monthTitle())
                            .font(.headline)
                        Spacer()

                        Button {
                            viewModel.moveMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding(.horizontal)

                    MonthGridView(
                        month: viewModel.selectedMonth,
                        selectedDate: $viewModel.selectedDate,
                        hasEvents: { day in viewModel.hasEvents(on: day) }
                    )
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if viewModel.eventsForSelectedDate.isEmpty {
                            Text("No events for this date")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.eventsForSelectedDate) { event in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(eventTypeColor(event.type ?? "").opacity(0.8))
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)

                                    VStack(alignment: .leading, spacing: 4) {
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
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
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

private struct MonthGridView: View {
    let month: Date
    @Binding var selectedDate: Date
    let hasEvents: (Date) -> Bool

    private let calendar = Calendar.current

    private var days: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        let leadingDays = calendar.dateComponents([.day], from: monthFirstWeek.start, to: monthInterval.start).day ?? 0
        let monthDays = calendar.range(of: .day, in: .month, for: month)?.count ?? 0

        var values: [Date?] = Array(repeating: nil, count: leadingDays)
        for day in 0..<monthDays {
            if let date = calendar.date(byAdding: .day, value: day, to: monthInterval.start) {
                values.append(date)
            }
        }
        while values.count % 7 != 0 {
            values.append(nil)
        }
        return values
    }

    var body: some View {
        VStack(spacing: 8) {
            let symbols = calendar.shortStandaloneWeekdaySymbols
            let shifted = Array(symbols.dropFirst()) + [symbols.first!]
            HStack {
                ForEach(shifted, id: \.self) { s in
                    Text(s)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .bold : .regular)
                                Circle()
                                    .fill(hasEvents(date) ? Color.blue : Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }
}
