import Foundation
import MagicKit
import MagicPlayMan
import ProviderPlayback

/// ControlButtons 所需的播放能力实现,由插件入口连接到内核 Provider。
@MainActor
final class PlaybackCapabilityAdapter: PlaybackCapability, SuperLog {
    nonisolated static let verbose = false

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var currentURL: URL? { playback.currentURL }

    var isPlaying: Bool { playback.isPlaying }

    var playMode: MagicPlayMode {
        MagicPlayMode(rawValue: playback.playMode.rawValue) ?? .sequence
    }

    func toggle() { playback.toggle() }

    func togglePlayMode() { playback.togglePlayMode() }

    func play(_ url: URL) async { await playback.play(url) }

    func reset() async { await playback.reset() }
}
