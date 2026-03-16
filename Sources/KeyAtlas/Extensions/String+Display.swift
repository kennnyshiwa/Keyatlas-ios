import Foundation

extension String {
    /// Convert plain text entered on iOS back into simple rich HTML.
    /// - Preserves line breaks/paragraphs
    /// - Auto-linkifies http/https URLs
    func keyAtlasPlainTextToHTML() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Basic escaping first
        var escaped = trimmed
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")

        // Linkify URLs
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let ns = escaped as NSString
            let matches = detector.matches(in: escaped, options: [], range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                guard let url = m.url else { continue }
                let raw = ns.substring(with: m.range)
                let anchor = "<a href=\"\(url.absoluteString)\">\(raw)</a>"
                escaped = (escaped as NSString).replacingCharacters(in: m.range, with: anchor)
            }
        }

        // Preserve paragraphs / line breaks
        let paragraphs = escaped
            .components(separatedBy: "\n\n")
            .map { p in "<p>\(p.replacingOccurrences(of: "\n", with: "<br/>") )</p>" }

        return paragraphs.joined(separator: "\n")
    }

    /// Convert common scraped HTML blobs into readable plain text for mobile UI.
    var keyAtlasDisplayText: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }

        var output = trimmed

        // 1) HTML -> plain text when needed (fully deterministic line-break preserving path)
        if trimmed.contains("<") && trimmed.contains(">") {
            output = trimmed
                .replacingOccurrences(of: #"(?is)<script[\s\S]*?</script>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?is)<style[\s\S]*?</style>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)</(p|div|li|h[1-6]|section|article|blockquote|tr|ul|ol)>"#, with: "\n", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)<li[^>]*>"#, with: "\n• ", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)<(p|div|h[1-6]|section|article|blockquote|tr|ul|ol)[^>]*>"#, with: "\n", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)</td>"#, with: "  ", options: .regularExpression)
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        }

        // 2) Decode common HTML entities (without re-parsing as HTML)
        output = output.keyAtlasDecodingHTMLEntities()

        // 3) Fix common mojibake apostrophes seen in imported content
        output = output
            .replacingOccurrences(of: "�", with: "'")
            .replacingOccurrences(of: "â€™", with: "’")
            .replacingOccurrences(of: "â€˜", with: "‘")
            .replacingOccurrences(of: "â€œ", with: "“")
            .replacingOccurrences(of: "â€", with: "”")
            .replacingOccurrences(of: "â€“", with: "–")
            .replacingOccurrences(of: "â€”", with: "—")
            .replacingOccurrences(of: "â€¦", with: "…")

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
    func keyAtlasDecodingHTMLEntities() -> String {
        var out = self
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        // numeric entities: decimal
        if let dec = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let ns = out as NSString
            let matches = dec.matches(in: out, options: [], range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                let raw = ns.substring(with: m.range(at: 1))
                if let code = Int(raw), let scalar = UnicodeScalar(code) {
                    out = (out as NSString).replacingCharacters(in: m.range(at: 0), with: String(Character(scalar)))
                }
            }
        }

        return out
    }

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
