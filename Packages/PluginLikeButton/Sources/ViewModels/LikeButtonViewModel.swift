import Combine
import Foundation
import MagicKit

/// 喜欢按钮的状态容器：当前文件与喜欢状态。
///
/// 经 `LikeButtonCapability` 读写播放与收藏状态（见 Capabilities 目录），
/// 不直接持有内核 `PlaybackProviding`。
@MainActor
final class LikeButtonViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var hasAsset = false
    @Published private(set) var isLiked = false
    /// 播放能力（Capabilities 目录收窄）。
    ///
    /// **强持有**：入口 teardown 先释放本容器再释放能力；能力内部对 Provider
    /// 为 `weak`，强持有能力不会延长播放 Provider 的生命周期。
    private let playback: (any LikeButtonCapability)?

    init(playback: (any LikeButtonCapability)?) {
        self.playback = playback
        hasAsset = playback?.hasAsset ?? false
        isLiked = playback?.currentURL.map { playback?.likedAssets.contains($0) ?? false } ?? false
    }

    func handleAssetChanged(_ url: URL?) {
        hasAsset = url != nil
        isLiked = url.map { playback?.likedAssets.contains($0) ?? false } ?? false
    }

    func handleLikeStatusChanged(_ liked: Bool) {
        isLiked = liked
    }

    func handleLikedAssetsChanged(_ assets: Set<URL>) {
        isLiked = playback?.currentURL.map { assets.contains($0) } ?? false
    }

    func toggleLike() { playback?.toggleCurrentLike() }
}
