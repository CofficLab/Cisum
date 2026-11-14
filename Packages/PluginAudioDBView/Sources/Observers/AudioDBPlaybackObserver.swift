import MagicKit
import OSLog

/// 音频库播放状态观察者：将播放能力的当前资源变化转发给列表 ViewModel。
@MainActor
final class AudioDBPlaybackObserver: SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.coffic.cisum", category: "AudioDB.Playback")

    private weak var viewModel: AudioListViewModel?
    private var handle: (any AudioLibraryPlaybackObserverHandle)?

    init(playback: any AudioLibraryPlaybackCapability, viewModel: AudioListViewModel) {
        self.viewModel = viewModel
        if Self.verbose {
            Self.log.info("\(Self.t)🚩 注册播放观察者")
        }
        viewModel.applyExternalPlayback(url: playback.currentURL)
        handle = playback.addObserver { [weak self] event in
            guard case .assetChanged(let url) = event else { return }
            if Self.verbose {
                Self.log.info("\(Self.t)📥 收到 assetChanged 事件：\(url?.path ?? "nil")")
            }
            self?.viewModel?.applyExternalPlayback(url: url)
        }
        if Self.verbose {
            Self.log.info("\(Self.t)✅ 播放观察者注册完成")
        }
    }

    func cancel() {
        if Self.verbose {
            Self.log.info("\(Self.t)🛑 取消播放观察者")
        }
        handle?.cancel()
        handle = nil
    }
}