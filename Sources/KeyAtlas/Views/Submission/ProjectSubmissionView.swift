import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Autosave Draft

private struct ProjectDraft: Codable {
    var title: String
    var slug: String
    var description: String
    var status: String
    var categoryId: String
    var estimatedDelivery: String
    var minPrice: String
    var maxPrice: String
    var gbStartDate: Date
    var gbEndDate: Date
    var showDatePickers: Bool
}

// MARK: - URL Import Response

private struct ImportSummary {
    let fieldsPrefilled: Int
    let linksDetected: Int
    let sectionsEstimated: Int
}

private struct URLImportResponse: Codable, Sendable {
    let title: String?
    let description: String?
    let status: String?
    let gbStartDate: String?
    let gbEndDate: String?
    let links: [ImportedLink]?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case title, description, status, links, tags
        case gbStartDate = "gb_start_date"
        case gbEndDate = "gb_end_date"
    }

    struct ImportedLink: Codable, Sendable {
        let title: String?
        let url: String?
    }
}

// MARK: - Submission View

struct ProjectSubmissionView: View {
    @Environment(\.dismiss) private var dismiss
    private let projectToEdit: Project?

    @State private var title = ""
    @State private var slug = ""
    @State private var description = ""
    @State private var status: ProjectStatus = .interestCheck
    @State private var categoryId = ""
    @State private var estimatedDelivery = ""
    @State private var minPrice = ""
    @State private var maxPrice = ""
    @State private var gbStartDate = Date()
    @State private var gbEndDate = Date()
    @State private var showDatePickers = false

    @State private var heroPhoto: PhotosPickerItem?
    @State private var heroImageData: Data?
    @State private var galleryPhotos: [PhotosPickerItem] = []
    @State private var galleryData: [Data] = []

    @State private var categories: [ProjectCategory] = []
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var currentSection = 0

    // Draft delete
    @State private var showDeleteDraftAlert = false
    @State private var isDeletingDraft = false

    // URL import
    @State private var importURL = ""
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var importSummary: ImportSummary?

    // Autosave
    @State private var autosaveTask: Task<Void, Never>?
    @State private var showRestoreDraftAlert = false

    // Duplicate from existing project
    @State private var showDuplicateSheet = false
    @State private var userProjects: [Project] = []
    @State private var isLoadingUserProjects = false

    private let sections = ["Import", "Basic Info", "Details", "Media", "Pricing & Dates"]

    private var draftKey: String {
        if let slug = projectToEdit?.slug { return "draft-\(slug)" }
        return "draft-new"
    }

    init(projectToEdit: Project? = nil) {
        self.projectToEdit = projectToEdit
        _title = State(initialValue: projectToEdit?.title ?? "")
        _slug = State(initialValue: projectToEdit?.slug ?? "")
        _description = State(initialValue: projectToEdit?.description?.keyAtlasDisplayText ?? "")
        _status = State(initialValue: projectToEdit?.status ?? .interestCheck)
        _categoryId = State(initialValue: projectToEdit?.categoryId ?? "")
        _estimatedDelivery = State(initialValue: projectToEdit?.estimatedDelivery ?? "")
        if let min = projectToEdit?.pricing?.minPrice {
            _minPrice = State(initialValue: String(Double(min) / 100.0))
        }
        if let max = projectToEdit?.pricing?.maxPrice {
            _maxPrice = State(initialValue: String(Double(max) / 100.0))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            Button {
                                withAnimation { currentSection = index }
                            } label: {
                                Text(section)
                                    .font(.subheadline)
                                    .fontWeight(currentSection == index ? .bold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(currentSection == index ? Color.accentColor.opacity(0.1) : .clear)
                            }
                            .foregroundStyle(currentSection == index ? .primary : .secondary)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()

                // Content
                TabView(selection: $currentSection) {
                    importSection.tag(0)
                    basicInfoSection.tag(1)
                    detailsSection.tag(2)
                    mediaSection.tag(3)
                    pricingSection.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(projectToEdit == nil ? "Submit Project" : "Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        autosaveTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(projectToEdit == nil ? "Submit" : "Save") {
                        Task { await submitProject() }
                    }
                    .disabled(title.isEmpty || isSubmitting)
                    .accessibilityLabel(projectToEdit == nil ? "Submit project" : "Save project")
                }

                // Delete Draft button for unpublished edits
                if let project = projectToEdit, project.published != true {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            showDeleteDraftAlert = true
                        } label: {
                            Label("Delete Draft", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                        .accessibilityLabel("Delete draft project")
                        .disabled(isDeletingDraft)
                    }
                }
            }
            .task {
                await loadCategories()
                checkForSavedDraft()
            }
            .alert("Restore Draft?", isPresented: $showRestoreDraftAlert) {
                Button("Restore") { restoreDraft() }
                Button("Discard", role: .destructive) { clearDraft() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A saved draft was found. Would you like to restore it?")
            }
            .alert("Delete Draft", isPresented: $showDeleteDraftAlert) {
                Button("Delete", role: .destructive) {
                    Task { await deleteDraft() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this draft project. This action cannot be undone.")
            }
            .alert("Import Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "Failed to import URL")
            }
            .sheet(isPresented: $showDuplicateSheet) {
                duplicatePickerView
            }
            // Autosave trigger
            .onChange(of: title) { _, _ in scheduleAutosave() }
            .onChange(of: slug) { _, _ in scheduleAutosave() }
            .onChange(of: description) { _, _ in scheduleAutosave() }
            .onChange(of: status) { _, _ in scheduleAutosave() }
            .onChange(of: categoryId) { _, _ in scheduleAutosave() }
            .onChange(of: estimatedDelivery) { _, _ in scheduleAutosave() }
            .onChange(of: minPrice) { _, _ in scheduleAutosave() }
            .onChange(of: maxPrice) { _, _ in scheduleAutosave() }
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Fast start: import from URL", systemImage: "bolt.horizontal.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Text("Paste a project URL and we'll prefill as much as possible before you continue through the full submission flow.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("https://...", text: $importURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Import URL")

                    Button {
                        Task { await importFromURL() }
                    } label: {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isImporting ? "Importing…" : "Import and prefill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(importURL.isEmpty || isImporting)
                    .accessibilityLabel("Import from URL and prefill form")
                }
                .padding(.vertical, 6)
            }

            if let summary = importSummary {
                Section("Import summary") {
                    HStack {
                        summaryCell(title: "Fields prefilled", value: summary.fieldsPrefilled)
                        summaryCell(title: "Links detected", value: summary.linksDetected)
                        summaryCell(title: "Sections estimated", value: summary.sectionsEstimated)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Import summary: \(summary.fieldsPrefilled) fields prefilled, \(summary.linksDetected) links detected, \(summary.sectionsEstimated) sections estimated")
                }
            }

            if projectToEdit == nil {
                Section {
                    Button {
                        Task { await loadUserProjectsForDuplicate() }
                        showDuplicateSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Start from Existing Project")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Duplicate existing project")
                }
            }
        }
    }

    private func summaryCell(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        Form {
            Section("Title") {
                TextField("Project title", text: $title)
                    .accessibilityLabel("Project title")
                    .onChange(of: title) { _, newValue in
                        if slug.isEmpty || slug == generateSlug(from: String(title.dropLast())) {
                            slug = generateSlug(from: newValue)
                        }
                    }
            }

            Section("Slug (URL)") {
                TextField("project-slug", text: $slug)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Project URL slug")
                Text("keyatlas.io/projects/\(slug)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach([ProjectStatus.interestCheck, .groupBuy], id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .accessibilityLabel("Project status")
            }

            Section("Category") {
                Picker("Category", selection: $categoryId) {
                    Text("Select…").tag("")
                    ForEach(categories) { cat in
                        Text(cat.name).tag(cat.id)
                    }
                }
                .accessibilityLabel("Project category")
            }

            if let error {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        Form {
            Section("Description") {
                TextEditor(text: $description)
                    .frame(minHeight: 200)
                    .accessibilityLabel("Project description")
            }

            Section("Estimated Delivery") {
                TextField("e.g. Q3 2026", text: $estimatedDelivery)
                    .accessibilityLabel("Estimated delivery")
            }
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        Form {
            Section("Hero Image") {
                if let data = heroImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                PhotosPicker(selection: $heroPhoto, matching: .images) {
                    Label("Select Hero Image", systemImage: "photo")
                }
                .accessibilityLabel("Select hero image")
            }

            Section("Gallery") {
                if !galleryData.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(galleryData.indices, id: \.self) { i in
                                if let img = UIImage(data: galleryData[i]) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                }

                PhotosPicker(selection: $galleryPhotos, maxSelectionCount: 20, matching: .images) {
                    Label("Add Gallery Images", systemImage: "photo.on.rectangle.angled")
                }
                .accessibilityLabel("Add gallery images")
            }
        }
        .onChange(of: heroPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    heroImageData = data
                }
            }
        }
        .onChange(of: galleryPhotos) { _, items in
            Task {
                var results: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        results.append(data)
                    }
                }
                galleryData = results
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        Form {
            Section("Pricing (USD)") {
                TextField("Min price (e.g. 150)", text: $minPrice)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Minimum price")
                TextField("Max price (e.g. 250)", text: $maxPrice)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Maximum price")
            }

            Section("Group Buy Dates") {
                Toggle("Set GB dates", isOn: $showDatePickers)
                if showDatePickers {
                    DatePicker("Start Date", selection: $gbStartDate, displayedComponents: .date)
                        .accessibilityLabel("Group buy start date")
                    DatePicker("End Date", selection: $gbEndDate, displayedComponents: .date)
                        .accessibilityLabel("Group buy end date")
                }
            }
        }
    }

    // MARK: - Duplicate Picker Sheet

    private var duplicatePickerView: some View {
        NavigationStack {
            Group {
                if isLoadingUserProjects {
                    ProgressView("Loading your projects…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if userProjects.isEmpty {
                    EmptyStateView(
                        title: "No Projects",
                        message: "You don't have any projects to duplicate.",
                        systemImage: "doc"
                    )
                } else {
                    List(userProjects) { project in
                        Button {
                            duplicateFrom(project)
                            showDuplicateSheet = false
                        } label: {
                            HStack(spacing: 12) {
                                CachedImage(url: project.heroImageUrl)
                                    .frame(width: 56, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(project.status.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityLabel("Duplicate \(project.title)")
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Start from Existing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDuplicateSheet = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadCategories() async {
        do {
            let response: PaginatedResponse<ProjectCategory> = try await APIClient.shared.request(
                path: "/api/v1/categories"
            )
            categories = response.data
        } catch {
            // Try array
            if let cats: [ProjectCategory] = try? await APIClient.shared.request(path: "/api/v1/categories") {
                categories = cats
            }
        }
    }

    private func importFromURL() async {
        isImporting = true
        defer { isImporting = false }

        struct ImportBody: Codable, Sendable { let url: String }

        do {
            let result: URLImportResponse = try await APIClient.shared.request(
                .post,
                path: "/api/import/url",
                body: ImportBody(url: importURL),
                authenticated: true
            )

            var fieldsPrefilled = 0

            // Only prefill empty fields
            if title.isEmpty, let t = result.title, !t.isEmpty {
                title = t
                fieldsPrefilled += 1
            }
            if description.isEmpty, let d = result.description, !d.isEmpty {
                description = d
                fieldsPrefilled += 1
            }
            if let s = result.status, let parsed = ProjectStatus(rawValue: s) {
                status = parsed
                fieldsPrefilled += 1
            }
            if let start = result.gbStartDate, !start.isEmpty, let date = start.asDate {
                gbStartDate = date
                showDatePickers = true
                fieldsPrefilled += 1
            }
            if let end = result.gbEndDate, !end.isEmpty, let date = end.asDate {
                gbEndDate = date
                showDatePickers = true
                fieldsPrefilled += 1
            }

            // Auto-generate slug if empty
            if slug.isEmpty && !title.isEmpty {
                slug = generateSlug(from: title)
                fieldsPrefilled += 1
            }

            let linksDetected = result.links?.compactMap(\.url).filter { !$0.isEmpty }.count ?? 0
            let sectionsEstimated = 1
                + ((result.description?.isEmpty == false) ? 1 : 0)
                + (linksDetected > 0 ? 1 : 0)
                + ((result.tags?.isEmpty == false) ? 1 : 0)
                + (((result.gbStartDate?.isEmpty == false) || (result.gbEndDate?.isEmpty == false)) ? 1 : 0)

            importSummary = ImportSummary(
                fieldsPrefilled: fieldsPrefilled,
                linksDetected: linksDetected,
                sectionsEstimated: sectionsEstimated
            )

            // Move to basic info after import
            withAnimation { currentSection = 1 }
        } catch {
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func loadUserProjectsForDuplicate() async {
        isLoadingUserProjects = true
        defer { isLoadingUserProjects = false }

        do {
            let response: APIDataResponse<UserProfile> = try await APIClient.shared.request(
                path: "/api/v1/profile",
                authenticated: true
            )
            userProjects = response.data.projects ?? []
        } catch {
            // Silently fail
        }
    }

    private func duplicateFrom(_ project: Project) {
        title = project.title + " (Copy)"
        slug = ""  // Force new slug
        description = project.description?.keyAtlasDisplayText ?? ""
        status = project.status
        categoryId = project.categoryId ?? ""
        estimatedDelivery = project.estimatedDelivery ?? ""
        if let min = project.pricing?.minPrice { minPrice = String(Double(min) / 100.0) }
        if let max = project.pricing?.maxPrice { maxPrice = String(Double(max) / 100.0) }
        if let start = project.gbStartDate?.asDate { gbStartDate = start; showDatePickers = true }
        if let end = project.gbEndDate?.asDate { gbEndDate = end; showDatePickers = true }

        // Generate new slug from new title
        slug = generateSlug(from: title)

        withAnimation { currentSection = 1 }
    }

    private func deleteDraft() async {
        guard let editSlug = projectToEdit?.slug else { return }
        isDeletingDraft = true
        defer { isDeletingDraft = false }

        do {
            try await APIClient.shared.requestVoid(.delete, path: "/api/v1/projects/\(editSlug)")
            clearDraft()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func submitProject() async {
        isSubmitting = true
        defer { isSubmitting = false }
        error = nil

        // Upload hero image first
        var heroUrl: String?
        if let heroData = heroImageData {
            do {
                let upload = try await APIClient.shared.upload(
                    path: "/api/v1/upload",
                    imageData: heroData,
                    filename: "hero.jpg"
                )
                heroUrl = upload.url
            } catch {
                self.error = "Hero image upload failed"
                return
            }
        }

        // Build submission body
        struct SubmitBody: Codable, Hashable, Sendable {
            let title: String
            let slug: String
            let description: String?
            let status: String
            let categoryId: String?
            let heroImageUrl: String?
            let estimatedDelivery: String?
            let minPrice: Int?
            let maxPrice: Int?
            let gbStartDate: String?
            let gbEndDate: String?

            enum CodingKeys: String, CodingKey {
                case title, slug, description, status
                case categoryId = "category_id"
                case heroImageUrl = "hero_image_url"
                case estimatedDelivery = "estimated_delivery"
                case minPrice = "min_price"
                case maxPrice = "max_price"
                case gbStartDate = "gb_start_date"
                case gbEndDate = "gb_end_date"
            }
        }

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]

        let body = SubmitBody(
            title: title,
            slug: slug,
            description: description.isEmpty ? nil : description,
            status: status.rawValue,
            categoryId: categoryId.isEmpty ? nil : categoryId,
            heroImageUrl: heroUrl,
            estimatedDelivery: estimatedDelivery.isEmpty ? nil : estimatedDelivery,
            minPrice: Int((Double(minPrice) ?? 0) * 100),
            maxPrice: Int((Double(maxPrice) ?? 0) * 100),
            gbStartDate: showDatePickers ? df.string(from: gbStartDate) : nil,
            gbEndDate: showDatePickers ? df.string(from: gbEndDate) : nil
        )

        do {
            if let editSlug = projectToEdit?.slug {
                try await APIClient.shared.requestVoid(.patch, path: "/api/v1/projects/\(editSlug)", body: body)
            } else {
                try await APIClient.shared.requestVoid(.post, path: "/api/v1/projects", body: body)

                // Upload gallery images for new project only
                for data in galleryData {
                    _ = try? await APIClient.shared.upload(
                        path: "/api/v1/projects/\(slug)/gallery",
                        imageData: data,
                        filename: "gallery-\(UUID().uuidString).jpg"
                    )
                }
            }

            // Clear autosave draft on success
            clearDraft()
            autosaveTask?.cancel()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func generateSlug(from text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    // MARK: - Autosave

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds debounce
            guard !Task.isCancelled else { return }
            saveDraft()
        }
    }

    private func saveDraft() {
        let draft = ProjectDraft(
            title: title,
            slug: slug,
            description: description,
            status: status.rawValue,
            categoryId: categoryId,
            estimatedDelivery: estimatedDelivery,
            minPrice: minPrice,
            maxPrice: maxPrice,
            gbStartDate: gbStartDate,
            gbEndDate: gbEndDate,
            showDatePickers: showDatePickers
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: draftKey)
        }
    }

    private func checkForSavedDraft() {
        // Only check for saved drafts in new project mode
        guard projectToEdit == nil else { return }
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(ProjectDraft.self, from: data),
              !draft.title.isEmpty else { return }
        showRestoreDraftAlert = true
    }

    private func restoreDraft() {
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(ProjectDraft.self, from: data) else { return }
        title = draft.title
        slug = draft.slug
        description = draft.description
        if let parsed = ProjectStatus(rawValue: draft.status) { status = parsed }
        categoryId = draft.categoryId
        estimatedDelivery = draft.estimatedDelivery
        minPrice = draft.minPrice
        maxPrice = draft.maxPrice
        gbStartDate = draft.gbStartDate
        gbEndDate = draft.gbEndDate
        showDatePickers = draft.showDatePickers
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
}
