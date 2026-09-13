import Foundation
import MagicPlayMan
import ProviderPlayback
import MagicKit

/// AudioPlayMode 需要的最小播放能力边界。
///
/// 插件在目标场景激活时恢复/同步播放模式；ViewModel 不直接持有
/// `PlaybackProviding` 或 `MagicPlayMan` 具体类型。
@MainActor
protocol AudioPlayModePlaybackCapability: AnyObject {
    /// 当前播放资源的 URL。
    var currentURL: URL? { get }

    /// 当前播放模式。
    var playMode: MagicPlayMode { get }

    /// 设置播放模式。
    func setPlayMode(_ mode: MagicPlayMode)
}

/// 将内核的 `PlaybackProviding` 适配成 AudioPlayMode 的播放能力。
@MainActor
final class AudioPlayModePlaybackCapabilityAdapter: AudioPlayModePlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var currentURL: URL? { playback.currentURL }

    var playMode: MagicPlayMode {
        MagicPlayMode(rawValue: playback.playMode.rawValue) ?? .sequence
    }

    func setPlayMode(_ mode: MagicPlayMode) {
        playback.setPlayMode(
            PlaybackMode(rawValue: mode.rawValue) ?? .sequence
        )
    }
}
