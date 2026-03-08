import SwiftUI
import NukeUI

/// Wrapper around NukeUI's LazyImage for consistent image loading
struct CachedImage: View {
    let url: String?
    var contentMode: ContentMode = .fill

    /// Resolve relative paths (e.g. "/uploads/...") against the API base URL.
    static let baseURL = URL(string: "https://keyatlas.io")!

    var body: some View {
        if let urlString = url, let imageURL = Self.resolveURL(urlString) {
            LazyImage(url: imageURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if state.error != nil {
                    placeholder
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            placeholder
        }
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
