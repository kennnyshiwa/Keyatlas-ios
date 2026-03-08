import SwiftUI
import Photos

/// Full-screen gallery carousel with thumbnail rail
struct ImageGalleryView: View {
    let images: [GalleryImage]
    @State private var selectedIndex = 0
    @State private var saveToast: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main image
                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        CachedImage(url: image.url, contentMode: .fit)
                            .tag(index)
                            .accessibilityLabel(image.caption ?? "Gallery image \(index + 1)")
                            .contextMenu {
                                Button {
                                    saveCurrentImage()
                                } label: {
                                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                                }
                                if let url = URL(string: image.url) ?? CachedImage.resolveURL(image.url) {
                                    ShareLink(item: url) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                            }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(maxHeight: .infinity)

                // Caption
                if let caption = images[safe: selectedIndex]?.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }

                // Thumbnail rail
                if images.count > 1 {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                                    CachedImage(url: image.url)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(index == selectedIndex ? Color.accentColor : .clear, lineWidth: 2)
                                        )
                                        .onTapGesture { selectedIndex = index }
                                        .id(index)
                                        .accessibilityLabel("Thumbnail \(index + 1)")
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 70)
                        .onChange(of: selectedIndex) { _, newValue in
                            withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                        }
                    }
                }
            }
            .background(.black)
            .overlay(alignment: .top) {
                if let toast = saveToast {
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 60)
                }
            }
            .animation(.easeInOut, value: saveToast)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            saveCurrentImage()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel("Save image to Photos")

                        Button("Done") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func saveCurrentImage() {
        guard let image = images[safe: selectedIndex] else { return }
        let urlStr = image.url

        // Resolve relative URLs
        guard let url = URL(string: urlStr) ?? CachedImage.resolveURL(urlStr) else {
            Task { await showToast("Invalid image URL") }
            return
        }

        Task {
            // Request photo library permission
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                await showToast("Photo library access denied")
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let uiImage = UIImage(data: data) else {
                    await showToast("Failed to load image")
                    return
                }

                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
                }
                await showToast("Saved to Photos ✓")
            } catch {
                await showToast("Save failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func showToast(_ message: String) {
        saveToast = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            saveToast = nil
        }
    }
}

/// Inline gallery preview (tappable to open full screen)
struct GalleryPreview: View {
    let images: [GalleryImage]
    @State private var showFullGallery = false

    var body: some View {
        if !images.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gallery")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images) { image in
                            CachedImage(url: image.url)
                                .frame(width: 120, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .onTapGesture { showFullGallery = true }
            }
            .fullScreenCover(isPresented: $showFullGallery) {
                ImageGalleryView(images: images)
            }
        }
    }
}

// Safe array subscript
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
