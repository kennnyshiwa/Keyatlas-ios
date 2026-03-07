import SwiftUI

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
            Form {
                Section("Title") {
                    TextField("Guide title", text: $title)
                }

                Section("Difficulty") {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(difficulties, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Cover Image URL") {
                    TextField("https://...", text: $heroImage)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 300)
                        .font(.body)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
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
            let body: [String: String?] = [
                "title": title.trimmingCharacters(in: .whitespaces),
                "content": content,
                "difficulty": difficulty,
                "heroImage": heroImage.isEmpty ? nil : heroImage,
            ]

            try await api.requestVoid(
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
