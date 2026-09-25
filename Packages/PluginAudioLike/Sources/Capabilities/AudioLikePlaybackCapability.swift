import ProviderPlayback
import Foundation
import MagicKit

/// AudioLike 需要的最小播放能力边界。
///
/// 插件仅在目标场景激活时依赖"播放服务可用"这一前提来启用喜欢保存；
/// ViewModel 不直接持有 `PlaybackProviding` 或 `MagicPlayMan`。
@MainActor
protocol AudioLikePlaybackCapability: AnyObject {
    /// 播放服务是否可用（喜欢保存激活的前提）。
    var isAvailable: Bool { get }
}

/// 将内核的 `PlaybackProviding` 适配成 AudioLike 的播放能力。
@MainActor
final class AudioLikePlaybackCapabilityAdapter: AudioLikePlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var isAvailable: Bool { true }
}