import ProviderPlayback
import Foundation
import MagicKit

/// 播放进度视图需要的最小播放能力。
///
/// ViewModel 只依赖这条能力边界；Provider 的解析与适配由插件入口完成。
@MainActor
protocol PlaybackProgressCapability: AnyObject {
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }

    func seek(toTime: TimeInterval)
}

/// 将内核播放 Provider 收窄成播放进度能力。
@MainActor
final class PlaybackProgressCapabilityAdapter: PlaybackProgressCapability, SuperLog {
    nonisolated static let verbose = false

    private weak var playback: (any PlaybackProviding)?

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var currentTime: TimeInterval { playback?.currentTime ?? 0 }
    var duration: TimeInterval { playback?.duration ?? 0 }

    func seek(toTime: TimeInterval) {
        playback?.seek(toTime: toTime)
    }
}