import SwiftUI
import WebKit

struct GuideEditView: View {
    let guide: Guide
    var onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var difficulty: String
    @State private var heroImage: String
    @State private var isSaving = false
    @State private var error: String?
    @State private var editorHeight: CGFloat = 400

    private let difficulties = ["Beginner", "Intermediate", "Advanced", "Expert"]
    private let api = APIClient.shared

    init(guide: Guide, onSave: (() -> Void)? = nil) {
        self.guide = guide
        self.onSave = onSave
        _title = State(initialValue: guide.title)
        _content = State(initialValue: guide.content ?? "")
        _difficulty = State(initialValue: guide.difficulty ?? "Beginner")
        _heroImage = State(initialValue: guide.heroImage ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title").font(.caption).foregroundStyle(.secondary)
                        TextField("Guide title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Difficulty
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Difficulty").font(.caption).foregroundStyle(.secondary)
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(difficulties, id: \.self) { level in
                                Text(level).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Cover Image
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cover Image URL").font(.caption).foregroundStyle(.secondary)
                        TextField("https://...", text: $heroImage)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    // Content (rich HTML editor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Content").font(.caption).foregroundStyle(.secondary)
                        RichHTMLEditor(html: $content, height: $editorHeight)
                            .frame(height: max(editorHeight, 400))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        error = nil

        do {
            let body: [String: String] = {
                var d: [String: String] = [
                    "title": title.trimmingCharacters(in: .whitespaces),
                    "content": content,
                    "difficulty": difficulty,
                ]
                if !heroImage.isEmpty {
                    d["heroImage"] = heroImage
                }
                return d
            }()

            // Use the generic request so we can ignore the response shape
            let _: EmptyResponse = try await api.request(
                .put,
                path: "/api/guides/\(guide.id)",
                body: body,
                authenticated: true
            )

            await MainActor.run {
                onSave?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isSaving = false
            }
        }
    }
}

/// A WKWebView-based rich text editor using contentEditable
struct RichHTMLEditor: UIViewRepresentable {
    @Binding var html: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "contentChanged")
        config.userContentController.add(context.coordinator, name: "heightChanged")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !context.coordinator.didLoad else { return }
        let escaped = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let page = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: 16px;
                line-height: 1.6;
                padding: 12px;
                min-height: 380px;
                -webkit-text-size-adjust: 100%;
            }
            @media (prefers-color-scheme: dark) {
                body { color: #e5e5e5; background: #1c1c1e; }
                h2, h3 { color: #ffffff; }
            }
            @media (prefers-color-scheme: light) {
                body { color: #1a1a1a; background: #ffffff; }
            }
            #editor { outline: none; min-height: 380px; }
            #editor:empty:before {
                content: "Write your guide content here...";
                color: #999;
            }
            h2 { font-size: 20px; font-weight: 700; margin: 20px 0 10px 0; }
            h3 { font-size: 17px; font-weight: 600; margin: 16px 0 8px 0; }
            p { margin: 6px 0; }
            ul, ol { margin: 6px 0; padding-left: 24px; }
            li { margin: 3px 0; }
            img { max-width: 100%; height: auto; border-radius: 8px; }
            #toolbar {
                display: flex; gap: 2px; padding: 8px 4px; border-bottom: 1px solid #ccc;
                position: sticky; top: 0; background: inherit; z-index: 10;
                flex-wrap: wrap;
            }
            @media (prefers-color-scheme: dark) {
                #toolbar { border-color: #444; }
            }
            #toolbar button {
                font-size: 14px; padding: 4px 8px; border: 1px solid #ccc;
                border-radius: 4px; background: transparent; color: inherit;
                min-width: 32px;
            }
            @media (prefers-color-scheme: dark) {
                #toolbar button { border-color: #555; }
            }
        </style>
        </head>
        <body>
        <div id="toolbar">
            <button onclick="exec('bold')"><b>B</b></button>
            <button onclick="exec('italic')"><i>I</i></button>
            <button onclick="exec('underline')"><u>U</u></button>
            <button onclick="wrapBlock('h2')">H2</button>
            <button onclick="wrapBlock('h3')">H3</button>
            <button onclick="exec('insertUnorderedList')">&#8226;</button>
            <button onclick="exec('insertOrderedList')">1.</button>
        </div>
        <div id="editor" contenteditable="true">\(escaped)</div>
        <script>
        function exec(cmd) { document.execCommand(cmd, false, null); notifyChange(); }
        function wrapBlock(tag) {
            document.execCommand('formatBlock', false, '<' + tag + '>');
            notifyChange();
        }
        function notifyChange() {
            const html = document.getElementById('editor').innerHTML;
            webkit.messageHandlers.contentChanged.postMessage(html);
            notifyHeight();
        }
        function notifyHeight() {
            const h = document.documentElement.scrollHeight;
            webkit.messageHandlers.heightChanged.postMessage(h);
        }
        document.getElementById('editor').addEventListener('input', notifyChange);
        window.addEventListener('load', function() { setTimeout(notifyHeight, 200); });
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(page, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: RichHTMLEditor
        weak var webView: WKWebView?
        var didLoad = false

        init(parent: RichHTMLEditor) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didLoad = true
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "contentChanged", let html = message.body as? String {
                DispatchQueue.main.async { self.parent.html = html }
            } else if message.name == "heightChanged", let h = message.body as? CGFloat {
                DispatchQueue.main.async { self.parent.height = h + 20 }
            }
        }
    }
}
