import Foundation
import ProviderPlayback
import MagicKit

/// Widget 控制所需的最小播放能力。
///
/// ViewModel 只依赖这个能力，不直接依赖 Kernel 或 `PlaybackProviding`；
/// 具体 Adapter 由 `AudioWidgetControlPlugin` 在生命周期组装阶段创建。
@MainActor
protocol AudioWidgetPlaybackCapability: AnyObject {
    var state: PlaybackStatus { get }
    var currentURL: URL? { get }
    var playMode: PlaybackMode { get }

    func toggle()
    func pause()
    func play(_ url: URL) async
}

/// 将内核播放 Provider 收窄成 Widget 控制插件所需的能力。
@MainActor
final class AudioWidgetPlaybackCapabilityAdapter: AudioWidgetPlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var state: PlaybackStatus { playback.state }
    var currentURL: URL? { playback.currentURL }
    var playMode: PlaybackMode { playback.playMode }

    func toggle() {
        playback.toggle()
    }

    func pause() {
        playback.pause()
    }

    func play(_ url: URL) async {
        await playback.play(url)
    }
}
