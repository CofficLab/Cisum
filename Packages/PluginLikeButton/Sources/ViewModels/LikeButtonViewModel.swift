import Combine
import Foundation
import MagicKit
import ProviderPlayback

@MainActor
final class LikeButtonViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var hasAsset = false
    @Published private(set) var isLiked = false
    private let playbackProvider: (any PlaybackProviding)?

    init(playbackProvider: (any PlaybackProviding)?) {
        self.playbackProvider = playbackProvider
        hasAsset = playbackProvider?.hasAsset ?? false
        isLiked = playbackProvider?.currentURL.map { playbackProvider?.likedAssets.contains($0) ?? false } ?? false
    }

    func handleAssetChanged(_ url: URL?) {
        hasAsset = url != nil
        isLiked = url.map { playbackProvider?.likedAssets.contains($0) ?? false } ?? false
    }

    func handleLikeStatusChanged(_ liked: Bool) {
        isLiked = liked
    }

    func handleLikedAssetsChanged(_ assets: Set<URL>) {
        isLiked = playbackProvider?.currentURL.map { assets.contains($0) } ?? false
    }

    func toggleLike() { playbackProvider?.toggleCurrentLike() }
}
