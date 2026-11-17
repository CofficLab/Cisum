import OSLog
import MagicKit

/// 有声书库播放状态观察者：把当前章节与播放状态变化转发到网格 ViewModel。
@MainActor
final class PlaybackObserver: SuperLog {
    nonisolated static let emoji = "🎧"
    nonisolated static let verbose = false

    private weak var viewModel: BookGridViewModel?
    private var handle: (any BookLibraryPlaybackObserverHandle)?

    init(playback: any BookLibraryPlaybackCapability, viewModel: BookGridViewModel) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookDBPlaybackObserver 初始化") }
        viewModel.handleAssetChanged(playback.currentURL)
        viewModel.handlePlaybackStateChanged(playback.state)
        handle = playback.addObserver { [weak self] event in
            switch event {
            case .assetChanged(let url):
                self?.viewModel?.handleAssetChanged(url)
            case .stateChanged(let state):
                self?.viewModel?.handlePlaybackStateChanged(state)
            }
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookDBPlaybackObserver 取消") }
        handle?.cancel()
        handle = nil
    }
}