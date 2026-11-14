import Foundation
import ProviderPlayback
import SwiftUI
import MagicKit

/// 播放进度的显示状态；外部播放变化只通过 Observer 写入。
///
/// 通过 `ProgressBarCapability` 读写播放位置（见 Capabilities 目录），
/// 不直接持有内核 `PlaybackProviding`。
///
/// 当播放状态为 `.loading(.downloading(progress))` 时，`downloadProgress` 非 nil，
/// 视图据此切换为下载进度条而非播放时间条。
@MainActor
final class PlaybackProgressViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    /// 当前下载进度（`0...1`）；`nil` 表示未处于下载态，显示正常播放进度条。
    @Published private(set) var downloadProgress: Double?

    /// 进度能力（Capabilities 目录收窄），`weak` 持有。
    private weak var playback: (any ProgressBarCapability)?

    init(playback: (any ProgressBarCapability)?) {
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
        let normalized = max(time.isFinite ? time : 0, 0)
        currentTime = normalized
        playback?.seek(toTime: normalized)
    }

    private func sync() {
        currentTime = playback?.currentTime ?? 0
        duration = playback?.duration ?? 0
    }

    /// 从当前播放状态提取下载进度；无参时从能力重新读取。
    private func syncDownloadState(state: PlaybackStatus? = nil) {
        let resolved = state ?? playback?.state ?? .idle
        downloadProgress = PlaybackProgressViewModel.extractDownloadProgress(from: resolved)
    }

    /// 从播放状态中提取下载进度；非下载态返回 `nil`。
    static func extractDownloadProgress(from state: PlaybackStatus) -> Double? {
        guard case .loading(.downloading(let progress)) = state else { return nil }
        return min(max(progress, 0), 1)
    }
}
