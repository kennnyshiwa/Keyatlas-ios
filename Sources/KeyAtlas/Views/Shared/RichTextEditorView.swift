@preconcurrency import WebKit
import SwiftUI

// MARK: - RichTextEditorView

/// A SwiftUI view wrapping WKWebView that provides rich-text (HTML) editing.
///
/// It loads `rich-text-editor.html` from the app bundle, injects the initial
/// HTML content via `window.setHTML(...)`, and receives updated HTML back
/// through a WKScriptMessageHandler.  The view auto-expands its height to
/// fit content so it works naturally inside a SwiftUI `Form`/`List`.
struct RichTextEditorView: UIViewRepresentable {

    @Binding var html: String

    // Minimum rendered height (matches the old TextEditor frame)
    var minHeight: CGFloat = 200

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

        var parent: RichTextEditorView
        /// The WebView we manage — kept weak to avoid retain cycles.
        weak var webView: WKWebView?
        /// Tracks whether the initial HTML has been injected.
        var isLoaded = false
        /// Pending HTML to inject once the page finishes loading.
        var pendingHTML: String?

        init(_ parent: RichTextEditorView) {
            self.parent = parent
        }

        // MARK: WKScriptMessageHandler

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            Task { @MainActor in
                switch message.name {
                case "contentChanged":
                    if let html = message.body as? String {
                        self.parent.html = html
                    }
                case "editorHeight":
                    if let raw = message.body as? Double {
                        let newHeight = max(self.parent.minHeight, CGFloat(raw) + 24)
                        if let wv = self.webView {
                            wv.invalidateIntrinsicContentSize()
                            // Notify the hosting SwiftUI hierarchy that layout changed
                            (wv as UIView).setNeedsLayout()
                            _ = newHeight  // height is handled via intrinsicContentSize override
                        }
                        // Store for intrinsic size
                        self.lastReportedHeight = newHeight
                        self.webView?.invalidateIntrinsicContentSize()
                    }
                default:
                    break
                }
            }
        }

        var lastReportedHeight: CGFloat = 200

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if let html = pendingHTML {
                injectHTML(html, into: webView)
                pendingHTML = nil
            }
        }

        func injectHTML(_ html: String, into webView: WKWebView) {
            // Escape backtick and backslash so we can embed inside a template literal
            let safe = html
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "window.setHTML(`\(safe)`);"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(
            context.coordinator, name: "contentChanged"
        )
        config.userContentController.add(
            context.coordinator, name: "editorHeight"
        )
        // Allow inline media (needed for images in content)
        config.allowsInlineMediaPlayback = true

        let webView = AutoHeightWebView(minHeight: minHeight, coordinator: context.coordinator)
        webView.configuration.userContentController // already set above via config

        // Appearance
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false   // parent Form scrolls
        webView.scrollView.bounces = false

        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Load the HTML file from the bundle.
        // Works in both SPM (Bundle.module) and Xcode project (Bundle.main) builds.
        let bundle: Bundle
        #if SWIFT_PACKAGE
        bundle = Bundle.module
        #else
        bundle = Bundle.main
        #endif
        if let htmlURL = bundle.url(forResource: "rich-text-editor", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
            context.coordinator.pendingHTML = html
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.isLoaded else {
            // Page not ready yet; queue the content
            coordinator.pendingHTML = html
            return
        }
        // Only push content into the WebView if it changed externally
        // (e.g. parent resets the binding).  We compare against what JS last posted.
        // To avoid an update loop we rely on the fact that JS debounces its posts:
        // if the parent's binding value equals what we last received, skip the inject.
        if html != coordinator.parent.html {
            coordinator.injectHTML(html, into: webView)
        }
    }
}

// MARK: - AutoHeightWebView

/// A WKWebView subclass that reports its intrinsic size based on the
/// HTML content height so SwiftUI can size the frame correctly.
private final class AutoHeightWebView: WKWebView {

    private let minHeight: CGFloat
    private weak var coordinator: RichTextEditorView.Coordinator?

    init(minHeight: CGFloat, coordinator: RichTextEditorView.Coordinator) {
        self.minHeight = minHeight
        self.coordinator = coordinator

        // Build the configuration here — we can't call super.init then set config
        let config = WKWebViewConfiguration()
        config.userContentController.add(coordinator, name: "contentChanged")
        config.userContentController.add(coordinator, name: "editorHeight")
        config.allowsInlineMediaPlayback = true

        super.init(frame: .zero, configuration: config)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override var intrinsicContentSize: CGSize {
        let height = coordinator?.lastReportedHeight ?? minHeight
        return CGSize(width: UIView.noIntrinsicMetric, height: max(minHeight, height))
    }
}
