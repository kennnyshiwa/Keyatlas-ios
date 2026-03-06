import SwiftUI

/// Renders comment content that may contain HTML with images.
/// Extracts plain text and image URLs, displaying them inline.
struct RichCommentView: View {
    let content: String

    var body: some View {
        let parts = parseContent(content)

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let text):
                    if !text.isEmpty {
                        Text(text)
                            .font(.subheadline)
                    }
                case .image(let url):
                    CachedImage(url: url)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private enum ContentPart {
        case text(String)
        case image(String)
    }

    private func parseContent(_ html: String) -> [ContentPart] {
        var parts: [ContentPart] = []
        var remaining = html

        // Pattern to find <img ... src="..." ...> tags
        let imgPattern = try! NSRegularExpression(
            pattern: #"<img\b[^>]*\bsrc\s*=\s*"([^"]+)"[^>]*/?\s*>"#,
            options: .caseInsensitive
        )

        while true {
            let range = NSRange(remaining.startIndex..., in: remaining)
            guard let match = imgPattern.firstMatch(in: remaining, range: range) else {
                // No more images, add remaining text
                let cleaned = stripHTML(remaining)
                if !cleaned.isEmpty {
                    parts.append(.text(cleaned))
                }
                break
            }

            let matchRange = Range(match.range, in: remaining)!
            let srcRange = Range(match.range(at: 1), in: remaining)!

            // Text before the image
            let beforeText = stripHTML(String(remaining[remaining.startIndex..<matchRange.lowerBound]))
            if !beforeText.isEmpty {
                parts.append(.text(beforeText))
            }

            // The image
            let src = String(remaining[srcRange])
            if src.hasPrefix("http") {
                parts.append(.image(src))
            }

            // Continue after the match
            remaining = String(remaining[matchRange.upperBound...])
        }

        return parts
    }

    private func stripHTML(_ html: String) -> String {
        // Remove HTML tags
        var result = html.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Decode common entities
        result = result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse whitespace
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}
