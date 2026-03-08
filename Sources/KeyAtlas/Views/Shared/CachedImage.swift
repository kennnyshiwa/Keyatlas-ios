import SwiftUI
import NukeUI
import Nuke

/// Wrapper around NukeUI's LazyImage for consistent image loading
struct CachedImage: View {
    let url: String?
    var contentMode: ContentMode = .fill
    /// Target display size — images are downsampled on decode to this size
    var targetSize: CGSize?
    /// Priority for loading (use .high for visible hero images, .low for offscreen thumbnails)
    var priority: ImageRequest.Priority = .normal

    /// Resolve relative paths (e.g. "/uploads/...") against the API base URL.
    static let baseURL = URL(string: "https://keyatlas.io")!

    var body: some View {
        if let urlString = url, let imageURL = Self.resolveURL(urlString) {
            LazyImage(request: makeRequest(url: imageURL)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if state.error != nil {
                    placeholder
                } else {
                    // Shimmer placeholder instead of spinner
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            ProgressView()
                                .tint(.secondary)
                        }
                }
            }
        } else {
            placeholder
        }
    }

    private func makeRequest(url: URL) -> ImageRequest {
        var processors: [ImageProcessing] = []

        // Downsample to target size on decode — hugely reduces memory and speeds up rendering
        if let size = targetSize {
            let scale = UIScreen.main.scale
            let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
            processors.append(ImageProcessors.Resize(size: pixelSize, contentMode: .aspectFit))
        }

        var request = ImageRequest(url: url, processors: processors)
        request.priority = priority
        return request
    }

    static func resolveURL(_ string: String) -> URL? {
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        // Relative path — resolve to absolute URL for consistent caching
        if let relative = URL(string: string, relativeTo: baseURL) {
            return relative.absoluteURL
        }
        return nil
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }
}

/// Avatar image with circular clip
struct AvatarImage: View {
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        CachedImage(url: url)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .accessibilityLabel("User avatar")
    }
}
