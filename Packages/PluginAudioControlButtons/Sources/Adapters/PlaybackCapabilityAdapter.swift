import Foundation
import MagicKit
import MagicPlayMan
import ProviderPlayback
import os

/// ControlButtons 所需的播放能力实现,由插件入口连接到内核 Provider。
@MainActor
final class PlaybackCapabilityAdapter: PlaybackCapability, SuperLog {
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "ControlButtons.Adapter")

    private let playback: any PlaybackProviding

    init(playback: any PlaybackProviding) {
        self.playback = playback
    }

    var currentURL: URL? { playback.currentURL }

    var isPlaying: Bool { playback.isPlaying }

    var playMode: MagicPlayMode {
        MagicPlayMode(rawValue: playback.playMode.rawValue) ?? .sequence
    }

    func toggle() {
        if Self.verbose {
            let asset = playback.currentURL?.lastPathComponent ?? "nil"
            let isPlaying = playback.isPlaying
            Self.log.info("\(Self.t)➡️ Forward toggle; asset=\(asset), isPlaying=\(isPlaying)")
        }
        playback.toggle()
    }

    func togglePlayMode() {
        if Self.verbose {
            let mode = playback.playMode.rawValue
            Self.log.info("\(Self.t)➡️ Forward togglePlayMode; mode=\(mode)")
        }
        playback.togglePlayMode()
    }

    func play(_ url: URL) async {
        if Self.verbose {
            Self.log.info("\(Self.t)➡️ Forward play: \(url.lastPathComponent)")
        }
        await playback.play(url)
    }

    func reset() async {
        if Self.verbose {
            Self.log.info("\(Self.t)➡️ Forward reset")
        }
        await playback.reset()
    }
}
