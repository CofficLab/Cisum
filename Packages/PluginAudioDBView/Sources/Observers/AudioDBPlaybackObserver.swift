import MagicKit
import OSLog
import ProviderPlayback

/// 音频库播放状态观察者：将播放服务的当前资源变化转发给列表 ViewModel。
@MainActor
final class AudioDBPlaybackObserver: SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "AudioDB.Playback")

    private weak var viewModel: AudioListViewModel?
    private var handle: (any PlaybackProvidingObserverHandle)?

    init(playback: (any PlaybackProviding)?, viewModel: AudioListViewModel) {
        self.viewModel = viewModel
        if Self.verbose {
            Self.log.info("\(Self.t)🚩 Registering playback observer; playback available=\(playback != nil)")
        }
        viewModel.applyExternalPlayback(url: playback?.currentURL)
        handle = playback?.addObserver { [weak self] event in
            guard case .assetChanged(let url) = event else { return }
            if Self.verbose {
                Self.log.info("\(Self.t)📥 Received assetChanged event: \(url?.path ?? "nil")")
            }
            self?.viewModel?.applyExternalPlayback(url: url)
        }
        if Self.verbose {
            Self.log.info("\(Self.t)✅ Playback observer registration completed")
        }
    }

    func cancel() {
        if Self.verbose {
            Self.log.info("\(Self.t)🛑 Cancelling playback observer")
        }
        handle?.cancel()
        handle = nil
    }
}
