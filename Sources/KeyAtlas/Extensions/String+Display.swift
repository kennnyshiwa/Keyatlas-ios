import Foundation

extension String {
    /// Convert common scraped HTML blobs into readable plain text for mobile UI.
    var keyAtlasDisplayText: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }

        var output = trimmed

        // 1) HTML -> plain text when needed
        if trimmed.contains("<") && trimmed.contains(">") {
            if let data = trimmed.data(using: .utf8),
               let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
               ) {
                output = attributed.string
            } else {
                // Hard fallback: strip tags if rich parsing fails
                output = trimmed.replacingOccurrences(
                    of: #"<[^>]+>"#,
                    with: " ",
                    options: .regularExpression
                )
            }
        }

        // 2) Decode common HTML entities if still present
        if output.contains("&") {
            let wrapped = "<span>\(output)</span>"
            if let data = wrapped.data(using: .utf8),
               let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
               ) {
                output = attributed.string
            }
        }

        // 3) Remove noisy URLs from scraped forum descriptions
        output = output.replacingOccurrences(
            of: #"https?://\S+"#,
            with: "",
            options: .regularExpression
        )

        // 4) Normalize whitespace/newlines
        output = output
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return output
    }
}
