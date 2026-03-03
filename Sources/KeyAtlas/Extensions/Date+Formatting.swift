import Foundation

extension String {
    /// Parse an ISO 8601 date string
    var asDate: Date? {
        let formatters: [ISO8601DateFormatter] = {
            let full = ISO8601DateFormatter()
            let dateOnly = ISO8601DateFormatter()
            dateOnly.formatOptions = [.withFullDate]
            return [full, dateOnly]
        }()
        for f in formatters {
            if let d = f.date(from: self) { return d }
        }
        // Fallback: try DateFormatter for common API patterns
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"] {
            df.dateFormat = fmt
            if let d = df.date(from: self) { return d }
        }
        return nil
    }

    /// Format as relative time (e.g. "2 days ago")
    var relativeTime: String {
        guard let date = self.asDate else { return self }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format as readable date (e.g. "Jan 15, 2026")
    var readableDate: String {
        guard let date = self.asDate else { return self }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
