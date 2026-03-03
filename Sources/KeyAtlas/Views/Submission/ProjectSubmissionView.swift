import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ProjectSubmissionView: View {
    @Environment(\.dismiss) private var dismiss
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

    private let sections = ["Basic Info", "Details", "Media", "Pricing & Dates"]

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
                    basicInfoSection.tag(0)
                    detailsSection.tag(1)
                    mediaSection.tag(2)
                    pricingSection.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Submit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submitProject() }
                    }
                    .disabled(title.isEmpty || isSubmitting)
                    .accessibilityLabel("Submit project")
                }
            }
            .task { await loadCategories() }
        }
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
            try await APIClient.shared.requestVoid(.post, path: "/api/v1/projects", body: body)

            // Upload gallery images
            for data in galleryData {
                _ = try? await APIClient.shared.upload(
                    path: "/api/v1/projects/\(slug)/gallery",
                    imageData: data,
                    filename: "gallery-\(UUID().uuidString).jpg"
                )
            }

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
}
