import Foundation
import OSLog
import SwiftUI

public extension URL {
    func coverFromMetadata(
        size: CGSize? = nil,
        verbose: Bool = false
    ) async throws -> Image? {
        guard let platformImage = try await extractCoverFromMetadata(verbose: verbose) else {
            return nil
        }

        if let size {
            return platformImage.resize(to: size).toSwiftUIImage()
        }

        return platformImage.toSwiftUIImage()
    }

    func thumbnail(
        size: CGSize = CGSize(width: 120, height: 120),
        useDefaultIcon: Bool = true,
        verbose: Bool,
        reason: String
    ) async throws -> ThumbnailResult? {
        let canUseCache = isDownloaded || isLocal

        if canUseCache, let cachedImage = ThumbnailCache.shared.fetch(for: self, size: size) {
            if verbose {
                os_log("\(self.t)(\(reason)) thumbnail cache hit")
            }

            return ThumbnailResult(
                image: cachedImage,
                isSystemIcon: false,
                fileType: thumbnailFileType,
                source: .cached,
                isCached: true
            )
        }

        let generator = ThumbnailGenerator(
            url: self,
            size: size,
            useDefaultIcon: useDefaultIcon,
            verbose: verbose,
            reason: reason
        )

        let result = try await generator.generate()
        if let result, !result.isSystemIcon, let image = result.image {
            ThumbnailCache.shared.save(image, for: self, size: size)
            return ThumbnailResult(
                image: image,
                isSystemIcon: result.isSystemIcon,
                fileType: result.fileType,
                source: result.source,
                isCached: true
            )
        }

        return result
    }

    func platformThumbnail(
        size: CGSize = CGSize(width: 120, height: 120),
        useDefaultIcon: Bool = true,
        verbose: Bool,
        reason: String
    ) async throws -> ThumbnailResult? {
        let generator = ThumbnailGenerator(
            url: self,
            size: size,
            useDefaultIcon: useDefaultIcon,
            verbose: verbose,
            reason: reason
        )
        return try await generator.generate()
    }

    static func thumbnailCacheDirectory() -> URL {
        ThumbnailCache.shared.getCacheDirectory()
    }
}

private extension URL {
    var thumbnailFileType: FileType {
        if isFolder { return .folder }
        if isImage { return .image }
        if isVideo { return .video }
        if isAudio { return .audio }
        if isDocument { return .document }
        return .unknown
    }
}
