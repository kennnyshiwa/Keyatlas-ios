import Foundation

extension String {
    /// Parse API date strings while preserving calendar day for date-only values.
    var asDate: Date? {
        // Treat date-only payloads as local calendar dates to avoid day-shift bugs.
        if self.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            return Self.dateOnlyFormatter.date(from: self)
        }

        // Many endpoints serialize date-only DB fields as midnight UTC.
        // Preserve the intended calendar day by mapping YYYY-MM-DD in local time.
        if self.range(of: #"^\d{4}-\d{2}-\d{2}T00:00:00(?:\.\d+)?Z$"#, options: .regularExpression) != nil {
            let dayPart = String(self.prefix(10))
            return Self.dateOnlyFormatter.date(from: dayPart)
        }

        let formatters: [ISO8601DateFormatter] = {
            let full = ISO8601DateFormatter()
            full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fullNoFraction = ISO8601DateFormatter()
            fullNoFraction.formatOptions = [.withInternetDateTime]
            return [full, fullNoFraction]
        }()
        for f in formatters {
            if let d = f.date(from: self) { return d }
        }

        // Fallback for non-ISO payloads
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"] {
            df.dateFormat = fmt
            if let d = df.date(from: self) { return d }
        }
        return nil
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

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

extension Project {
    var commentCount: Int {
        apiCommentCount ?? comments?.count ?? 0
    }

    var isRecentlyUpdated: Bool {
        guard let date = updatedAt.asDate else { return false }
        return date >= Calendar.current.date(byAdding: .day, value: -14, to: Date())!
    }

    var trendingScore: Int {
        let followScore = (followCount ?? 0) * 4
        let favoriteScore = (favoriteCount ?? 0) * 3
        let commentScore = commentCount * 2

        let recentBoost: Int
        if let updated = updatedAt.asDate,
           let days = Calendar.current.dateComponents([.day], from: updated, to: Date()).day {
            recentBoost = max(0, 14 - max(0, days))
        } else {
            recentBoost = 0
        }

        return followScore + favoriteScore + commentScore + recentBoost
    }
}
