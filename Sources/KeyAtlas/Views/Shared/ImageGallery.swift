import SwiftUI

/// Full-screen gallery carousel with thumbnail rail
struct ImageGalleryView: View {
    let images: [GalleryImage]
    @State private var selectedIndex = 0
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
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
