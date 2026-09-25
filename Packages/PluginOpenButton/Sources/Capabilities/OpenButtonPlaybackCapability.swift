import ProviderPlayback
import Foundation
import MagicKit

/// OpenButton 需要的最小播放能力边界。
///
/// 插件依赖"播放服务可用"来展示当前播放资源；
/// ViewModel 不直接持有 `PlaybackProviding` 具体类型。
@MainActor
protocol OpenButtonPlaybackCapability: AnyObject {
    /// 当前播放资源 URL。
    var currentURL: URL? { get }
}

/// 将内核的 `PlaybackProviding` 适配成 OpenButton 的播放能力。
@MainActor
final class OpenButtonPlaybackCapabilityAdapter: OpenButtonPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var currentURL: URL? { playback.currentURL }
}