import Foundation
import SwiftUI
import MagicKit
import ProviderPlayback

/// 播放进度的显示状态；外部播放变化只通过 Observer 写入。
@MainActor
final class PlaybackProgressViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private weak var playbackProvider: (any PlaybackProviding)?

    init(playbackProvider: (any PlaybackProviding)?) {
        self.playbackProvider = playbackProvider
        sync()
    }

    func handleTimeChanged(_ currentTime: TimeInterval) {
        self.currentTime = currentTime
    }

    func handleDurationChanged(_ duration: TimeInterval) {
        self.duration = duration
    }

    func handleAssetChanged() {
        sync()
    }

    func seek(to time: TimeInterval) {
        let normalized = max(time.isFinite ? time : 0, 0)
        currentTime = normalized
        playbackProvider?.seek(toTime: normalized)
    }

    private func sync() {
        currentTime = playbackProvider?.currentTime ?? 0
        duration = playbackProvider?.duration ?? 0
    }
}
