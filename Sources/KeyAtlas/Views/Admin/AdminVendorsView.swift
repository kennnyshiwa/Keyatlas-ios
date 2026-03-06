import SwiftUI

struct AdminVendorsView: View {
    @State private var viewModel = AdminVendorsViewModel()
    @State private var showCreateSheet = false
    @State private var vendorToEdit: AdminVendor?
    @State private var vendorToDelete: AdminVendor?
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.vendors.isEmpty {
                ProgressView("Loading vendors…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.vendors.isEmpty {
                ErrorView(message: error) { await viewModel.load() }
            } else if viewModel.vendors.isEmpty {
                EmptyStateView(
                    title: "No Vendors",
                    message: "Create your first vendor using the + button.",
                    systemImage: "building.2"
                )
            } else {
                List {
                    ForEach(viewModel.vendors) { vendor in
                        AdminVendorRowView(vendor: vendor) {
                            vendorToEdit = vendor
                        } onDelete: {
                            vendorToDelete = vendor
                            showDeleteConfirm = true
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Manage Vendors")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create vendor")
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(isPresented: $showCreateSheet) {
            AdminVendorFormView(viewModel: viewModel, vendor: nil)
        }
        .sheet(item: $vendorToEdit) { vendor in
            AdminVendorFormView(viewModel: viewModel, vendor: vendor)
        }
        .alert("Delete Vendor", isPresented: $showDeleteConfirm, presenting: vendorToDelete) { vendor in
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteVendor(vendor) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { vendor in
            Text("Are you sure you want to delete \"\(vendor.name)\"? This action cannot be undone.")
        }
    }
}

private struct AdminVendorRowView: View {
    let vendor: AdminVendor
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarImage(url: vendor.logo, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(vendor.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Text(vendor.slug)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let region = vendor.region, !region.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(region)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let projectCount = vendor.projectCount {
                    Text("\(projectCount) project\(projectCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Edit \(vendor.name)")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Delete \(vendor.name)")
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AdminVendorFormView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: AdminVendorsViewModel
    let vendor: AdminVendor?

    @State private var name = ""
    @State private var slug = ""
    @State private var website = ""
    @State private var region = ""
    @State private var isSubmitting = false
    @State private var error: String?

    var isEditing: Bool { vendor != nil }

    init(viewModel: AdminVendorsViewModel, vendor: AdminVendor?) {
        self.viewModel = viewModel
        self.vendor = vendor
        _name = State(initialValue: vendor?.name ?? "")
        _slug = State(initialValue: vendor?.slug ?? "")
        _website = State(initialValue: vendor?.website ?? "")
        _region = State(initialValue: vendor?.region ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vendor Info") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Vendor name")
                        .onChange(of: name) { _, newValue in
                            if !isEditing && (slug.isEmpty || slug == generateSlug(from: String(name.dropLast()))) {
                                slug = generateSlug(from: newValue)
                            }
                        }

                    TextField("Slug", text: $slug)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Vendor slug")

                    TextField("Website URL", text: $website)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Vendor website URL")

                    TextField("Region (e.g. US, EU)", text: $region)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Vendor region")
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Vendor" : "New Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(name.isEmpty || slug.isEmpty || isSubmitting)
                    .accessibilityLabel(isEditing ? "Save vendor" : "Create vendor")
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        error = nil

        do {
            if let vendor {
                try await viewModel.updateVendor(
                    vendor,
                    name: name,
                    slug: slug,
                    website: website.isEmpty ? nil : website,
                    region: region.isEmpty ? nil : region
                )
            } else {
                try await viewModel.createVendor(
                    name: name,
                    slug: slug,
                    website: website.isEmpty ? nil : website,
                    region: region.isEmpty ? nil : region
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
