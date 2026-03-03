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
            }
        }

        // 2) Remove noisy URLs from scraped forum descriptions
        output = output.replacingOccurrences(
            of: #"https?://\S+"#,
            with: "",
            options: .regularExpression
        )

        // 3) Normalize whitespace/newlines
        output = output
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return output
    }
}
