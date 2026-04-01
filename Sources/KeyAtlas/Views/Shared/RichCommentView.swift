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
                        styledMentionText(text)
                    }
                case .image(let url):
                    CachedImage(url: url, contentMode: .fit)
                        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    /// Renders text with @mentions highlighted in accent color
    private func styledMentionText(_ text: String) -> Text {
        let mentionPattern = try! NSRegularExpression(pattern: #"@\w+"#)
        let nsText = text as NSString
        let matches = mentionPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        if matches.isEmpty {
            return Text(text).font(.subheadline)
        }

        var result = Text("")
        var cursor = 0

        for match in matches {
            let matchRange = match.range
            // Text before mention
            if matchRange.location > cursor {
                let before = nsText.substring(with: NSRange(location: cursor, length: matchRange.location - cursor))
                result = result + Text(before).font(.subheadline)
            }
            // The mention itself
            let mention = nsText.substring(with: matchRange)
            result = result + Text(mention).font(.subheadline).foregroundColor(.accentColor).fontWeight(.medium)
            cursor = matchRange.location + matchRange.length
        }

        // Trailing text
        if cursor < nsText.length {
            let trailing = nsText.substring(from: cursor)
            result = result + Text(trailing).font(.subheadline)
        }

        return result
    }

    private enum ContentPart {
        case text(String)
        case image(String)
    }

    private func parseContent(_ html: String) -> [ContentPart] {
        var parts: [ContentPart] = []

        // Pre-process: replace mention <a> tags with plain @mention text before stripping
        let mentionPattern = try! NSRegularExpression(
            pattern: #"<a[^>]*data-mention="([^"]*)"[^>]*>[^<]*</a>"#,
            options: .caseInsensitive
        )
        var preprocessed = html
        let mentionMatches = mentionPattern.matches(in: preprocessed, range: NSRange(location: 0, length: (preprocessed as NSString).length))
        for match in mentionMatches.reversed() {
            let fullRange = Range(match.range, in: preprocessed)!
            let usernameRange = Range(match.range(at: 1), in: preprocessed)!
            let username = String(preprocessed[usernameRange])
            preprocessed.replaceSubrange(fullRange, with: "@\(username)")
        }

        var remaining = preprocessed

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

            // The image — resolve relative paths against base URL
            let src = String(remaining[srcRange])
            if src.hasPrefix("http") {
                parts.append(.image(src))
            } else if src.hasPrefix("/") {
                parts.append(.image("https://keyatlas.io\(src)"))
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
