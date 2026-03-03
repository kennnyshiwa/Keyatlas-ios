import Foundation

@Observable
final class CalendarViewModel: @unchecked Sendable {
    var events: [CalendarEvent] = []
    var deliveries: [DeliveryQuarter] = []
    var isLoading = false
    var error: String?
    var selectedMonth = Date()

    private let api = APIClient.shared

    func loadCalendar() async {
        await MainActor.run { self.isLoading = true; self.error = nil }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let response: CalendarResponse = try await api.request(path: "/api/v1/calendar")
            await MainActor.run {
                self.events = response.events ?? []
                self.deliveries = response.deliveries ?? []
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    var eventsForSelectedMonth: [CalendarEvent] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedMonth)
        let year = calendar.component(.year, from: selectedMonth)

        return events.filter { event in
            guard let date = parseDate(event.date) else { return false }
            return calendar.component(.month, from: date) == month
                && calendar.component(.year, from: date) == year
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }
}
