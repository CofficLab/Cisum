import Foundation
import OSLog
import MagicPlayMan
import ProviderPlayback
import MagicKit

/// 播放观察者：订阅 `PlaybackProviding` 的播放事件，转发到
/// `BookControlViewModel`（状态 / 播放模式 / 上下章节请求）。
@MainActor
final class BookControlPlaybackObserver: SuperLog {
    nonisolated static let emoji = "🎧"
    nonisolated static let verbose = false

    private weak var viewModel: BookControlViewModel?
    private var playbackHandle: (any PlaybackProvidingObserverHandle)?

    init(playback: any PlaybackProviding, viewModel: BookControlViewModel) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookControlPlaybackObserver 初始化") }
        playbackHandle = playback.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .stateChanged(let state):
                self.viewModel?.applyStateChanged(state)
            case .playModeChanged(let mode):
                self.viewModel?.applyPlayModeChanged(
                    MagicPlayMode(rawValue: mode.rawValue) ?? .sequence
                )
            case .previousRequested(let asset):
                self.viewModel?.handlePreviousRequested(asset)
            case .nextRequested(let asset):
                self.viewModel?.handleNextRequested(asset)
            default:
                break
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookControlPlaybackObserver 取消") }
        playbackHandle?.cancel()
        playbackHandle = nil
    }
}
