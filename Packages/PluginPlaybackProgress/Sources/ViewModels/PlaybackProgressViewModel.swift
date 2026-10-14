import Foundation
import SwiftUI
import MagicKit

/// 播放进度的显示状态；外部播放变化只通过 Observer 写入。
///
/// 通过 `ProgressBarCapability` 读写播放位置（见 Capabilities 目录），
/// 不直接持有内核 `PlaybackProviding`。
@MainActor
final class PlaybackProgressViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    /// 进度能力（Capabilities 目录收窄），`weak` 持有。
    private weak var playback: (any ProgressBarCapability)?

    init(playback: (any ProgressBarCapability)?) {
        self.playback = playback
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
        playback?.seek(toTime: normalized)
    }

    private func sync() {
        currentTime = playback?.currentTime ?? 0
        duration = playback?.duration ?? 0
    }
}
