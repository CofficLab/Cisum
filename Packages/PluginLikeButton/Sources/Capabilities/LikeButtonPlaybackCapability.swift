import ProviderPlayback
import Foundation
import MagicKit

/// LikeButton 需要的最小播放能力边界。
///
/// 插件依赖"播放服务可用"来展示喜欢按钮状态；
/// ViewModel 不直接持有 `PlaybackProviding` 具体类型。
@MainActor
protocol LikeButtonPlaybackCapability: AnyObject {
    /// 是否有正在播放的资源。
    var hasAsset: Bool { get }

    /// 当前播放资源 URL。
    var currentURL: URL? { get }

    /// 已喜欢的资源 URL 列表。
    var likedAssets: [URL] { get }

    /// 切换当前资源的喜欢状态。
    func toggleCurrentLike()
}

/// 将内核的 `PlaybackProviding` 适配成 LikeButton 的播放能力。
@MainActor
final class LikeButtonPlaybackCapabilityAdapter: LikeButtonPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var hasAsset: Bool { playback.hasAsset }

    var currentURL: URL? { playback.currentURL }

    var likedAssets: [URL] { Array(playback.likedAssets) }

    func toggleCurrentLike() {
        playback.toggleCurrentLike()
    }
}