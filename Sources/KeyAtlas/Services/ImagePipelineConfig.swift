import Foundation
import Nuke

enum ImagePipelineConfig {
    static func setup() {
        // Aggressive disk cache: 300MB, images persist across launches
        let dataCache = try? DataCache(name: "com.kennnyshiwa.KeyAtlas.ImageCache")
        dataCache?.sizeLimit = 300 * 1024 * 1024 // 300 MB

        var config = ImagePipeline.Configuration.withDataCache

        if let dataCache {
            config.dataCache = dataCache
        }

        // In-memory cache: 100MB
        config.imageCache = ImageCache(costLimit: 100 * 1024 * 1024)

        // Resize images on decode to save memory
        config.isDecompressionEnabled = true

        // Allow progressive JPEG rendering
        config.isProgressiveDecodingEnabled = true

        // Deduplicate requests for same URL
        config.isTaskCoalescingEnabled = true

        // Rate limit to avoid overwhelming the server
        config.isRateLimiterEnabled = true

        ImagePipeline.shared = ImagePipeline(configuration: config)
    }
}
