import SwiftUI
import WebKit

struct GuideDetailView: View {
    let slug: String
    @State private var viewModel = GuideViewModel()
    @State private var showEditSheet = false
    @Environment(AuthService.self) private var authService

    private var canEdit: Bool {
        guard let user = authService.currentUser,
              let guide = viewModel.selectedGuide else { return false }
        return guide.author?.id == user.id || user.isAdmin
    }

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
                                DynamicHTMLView(html: content)
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
        .toolbar {
            if canEdit, let guide = viewModel.selectedGuide {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let guide = viewModel.selectedGuide {
                GuideEditView(guide: guide) {
                    Task { await viewModel.loadGuide(slug: slug) }
                }
            }
        }
        .task { await viewModel.loadGuide(slug: slug) }
    }
}

/// SwiftUI wrapper that renders HTML in a WKWebView with dynamic height
struct DynamicHTMLView: View {
    let html: String
    @State private var contentHeight: CGFloat = 100

    var body: some View {
        HTMLWebView(html: html, contentHeight: $contentHeight)
            .frame(height: contentHeight)
    }
}

struct HTMLWebView: UIViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
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
        let parent: HTMLWebView
        init(parent: HTMLWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                    if let height = result as? CGFloat, height > 0 {
                        DispatchQueue.main.async {
                            self?.parent.contentHeight = height
                        }
                    }
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
