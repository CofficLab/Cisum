import Foundation
import ProviderPlayback
import MagicKit

/// 播放设置页需要的最小播放状态能力。
///
/// 设置 ViewModel 不直接依赖内核的 `PlaybackProviding`；Provider 由
/// `PluginPlayBack` 在组装阶段适配成这条能力边界。
@MainActor
protocol PlaybackSettingsCapability: AnyObject {
    var currentURL: URL? { get }
    var isPlaying: Bool { get }
    var state: PlaybackStatus { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
}

/// 将内核播放 Provider 收窄成设置页所需的状态能力。
@MainActor
final class PlaybackSettingsCapabilityAdapter: PlaybackSettingsCapability, SuperLog {
    nonisolated static let verbose = false

    private weak var playback: (any PlaybackProviding)?

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var currentURL: URL? { playback?.currentURL }
    var isPlaying: Bool { playback?.isPlaying ?? false }
    var state: PlaybackStatus { playback?.state ?? .idle }
    var currentTime: TimeInterval { playback?.currentTime ?? 0 }
    var duration: TimeInterval { playback?.duration ?? 0 }
}
