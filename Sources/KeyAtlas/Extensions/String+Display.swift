import Foundation

extension String {
    /// Convert common scraped HTML blobs into readable plain text for mobile UI.
    var keyAtlasDisplayText: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }

        var output = trimmed

        // 1) HTML -> plain text when needed (preserve visual line breaks)
        if trimmed.contains("<") && trimmed.contains(">") {
            var html = trimmed
            // Preserve breaks for common block tags before attributed conversion
            html = html.replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            html = html.replacingOccurrences(of: #"(?i)</(p|div|li|h[1-6]|section|article|blockquote|tr)>"#, with: "\n", options: .regularExpression)
            html = html.replacingOccurrences(of: #"(?i)<(p|div|li|h[1-6]|section|article|blockquote|tr)[^>]*>"#, with: "\n", options: .regularExpression)

            let fallbackPlain = html
                .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)

            if let data = html.data(using: .utf8),
               let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
               ) {
                output = attributed.string

                // If attributed parsing collapses too aggressively, use fallback with preserved breaks
                let attributedNewlines = output.filter { $0 == "\n" }.count
                let fallbackNewlines = fallbackPlain.filter { $0 == "\n" }.count
                if fallbackNewlines > attributedNewlines {
                    output = fallbackPlain
                }
            } else {
                // Hard fallback: strip tags while keeping inserted newlines above
                output = fallbackPlain
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

        // 3) Fix common mojibake apostrophes seen in imported content
        output = output.replacingOccurrences(of: "�", with: "'")

        // 4) Insert safe breakpoints for long unbroken runs (causes horizontal overflow on iOS)
        output = output.keyAtlasSoftWrappedLongRuns(limit: 32)

        // 5) Normalize whitespace/newlines while preserving paragraph structure
        output = output
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return output
    }

    /// Add zero-width break opportunities to very long unbroken runs to prevent horizontal overflow.
    func keyAtlasSoftWrappedLongRuns(limit: Int = 32) -> String {
        guard !isEmpty else { return self }

        var result = ""
        var run = ""

        for ch in self {
            if ch.isWhitespace || ch.isNewline {
                if run.count > limit {
                    result += run.chunkedWithZeroWidthSpace(every: limit)
                } else {
                    result += run
                }
                run.removeAll(keepingCapacity: true)
                result.append(ch)
            } else {
                run.append(ch)
            }
        }

        if run.count > limit {
            result += run.chunkedWithZeroWidthSpace(every: limit)
        } else {
            result += run
        }

        return result
    }
}

private extension String {
    func chunkedWithZeroWidthSpace(every size: Int) -> String {
        guard size > 0, count > size else { return self }
        var out = ""
        var i = startIndex
        var step = 0
        while i < endIndex {
            out.append(self[i])
            step += 1
            if step == size {
                out.append("\u{200B}")
                step = 0
            }
            i = index(after: i)
        }
        return out
    }
}
