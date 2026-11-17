import Foundation
import ProviderPlayback
import SwiftUI

/// 书籍章节进度条的显示状态；播放变化只经 Observer 写入。
@MainActor
final class BookProgressBarViewModel: ObservableObject {
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    /// 当前下载进度（`0...1`）；`nil` 表示未处于下载态。
    @Published private(set) var downloadProgress: Double?

    private weak var playback: (any BookProgressBarCapability)?

    init(playback: (any BookProgressBarCapability)?) {
        self.playback = playback
        sync()
        syncDownloadState()
    }

    func handleTimeChanged(_ currentTime: TimeInterval) {
        self.currentTime = currentTime
    }

    func handleDurationChanged(_ duration: TimeInterval) {
        self.duration = duration
    }

    func handleAssetChanged() {
        sync()
        syncDownloadState()
    }

    func handleStateChanged(_ state: PlaybackStatus) {
        syncDownloadState(state: state)
    }

    func seek(to time: TimeInterval) {
        guard playback?.isCurrentAssetBook != false else { return }
        let normalized = max(time.isFinite ? time : 0, 0)
        currentTime = normalized
        playback?.seek(toTime: normalized)
    }

    private func sync() {
        guard playback?.isCurrentAssetBook != false else {
            currentTime = 0
            duration = 0
            return
        }
        currentTime = playback?.currentTime ?? 0
        duration = playback?.duration ?? 0
    }

    private func syncDownloadState(state: PlaybackStatus? = nil) {
        guard playback?.isCurrentAssetBook != false else {
            downloadProgress = nil
            return
        }
        let resolved = state ?? playback?.state ?? .idle
        downloadProgress = BookProgressBarViewModel.extractDownloadProgress(from: resolved)
    }

    /// 从播放状态中提取下载进度；非下载态返回 `nil`。
    static func extractDownloadProgress(from state: PlaybackStatus) -> Double? {
        guard case .loading(.downloading(let progress)) = state else { return nil }
        return min(max(progress, 0), 1)
    }
}
