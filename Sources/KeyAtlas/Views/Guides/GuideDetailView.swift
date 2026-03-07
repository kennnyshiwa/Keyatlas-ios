import SwiftUI
import WebKit

struct GuideDetailView: View {
    let slug: String
    @State private var viewModel = GuideViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.selectedGuide == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.selectedGuide == nil {
                ErrorView(message: error) { await viewModel.loadGuide(slug: slug) }
            } else if let guide = viewModel.selectedGuide {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Hero
                        if guide.heroImage != nil {
                            CachedImage(url: guide.heroImage)
                                .frame(height: 200)
                                .clipped()
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(guide.title)
                                .font(.title)
                                .fontWeight(.bold)

                            HStack {
                                if let author = guide.author {
                                    AvatarImage(url: author.effectiveAvatarUrl, size: 28)
                                    Text(author.displayName)
                                        .font(.subheadline)
                                }
                                Spacer()
                                Text(guide.createdAt.readableDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let difficulty = guide.difficulty {
                                Text(difficulty)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }

                            if let content = guide.content, !content.isEmpty {
                                HTMLContentView(html: content)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                ErrorView(message: "Unable to load guide") { await viewModel.loadGuide(slug: slug) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadGuide(slug: slug) }
    }
}

/// Renders HTML content using WKWebView with dynamic height
struct HTMLContentView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width - 32, height: 100), configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: 16px;
                line-height: 1.6;
                color: #1a1a1a;
                padding: 0;
                -webkit-text-size-adjust: 100%;
            }
            @media (prefers-color-scheme: dark) {
                body { color: #e5e5e5; }
                h2, h3 { color: #ffffff; }
            }
            h2 { font-size: 20px; font-weight: 700; margin: 24px 0 12px 0; }
            h3 { font-size: 17px; font-weight: 600; margin: 20px 0 8px 0; }
            p { margin: 8px 0; }
            ul, ol { margin: 8px 0; padding-left: 24px; }
            li { margin: 4px 0; }
            img { max-width: 100%; height: auto; border-radius: 8px; margin: 8px 0; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak webView] result, _ in
                guard let webView, let height = result as? CGFloat, height > 0 else { return }
                DispatchQueue.main.async {
                    webView.constraints.filter { $0.firstAttribute == .height }.forEach { webView.removeConstraint($0) }
                    let constraint = webView.heightAnchor.constraint(equalToConstant: height)
                    constraint.isActive = true
                    webView.superview?.setNeedsLayout()
                }
            }
        }
    }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                subview.place(at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ), proposal: .unspecified)
            }
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}
