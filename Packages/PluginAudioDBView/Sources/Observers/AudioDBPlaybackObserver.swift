import ProviderPlayback
import MagicKit
import OSLog

/// 音频库播放状态观察者：将播放服务的当前资源变化转发给列表 ViewModel。
@MainActor
final class AudioDBPlaybackObserver: SuperLog {
    nonisolated static let emoji = "🎵"
    nonisolated static let verbose = true

    private weak var viewModel: AudioListViewModel?
    private var handle: (any PlaybackProvidingObserverHandle)?

    init(playback: (any PlaybackProviding)?, viewModel: AudioListViewModel) {
        self.viewModel = viewModel
        if Self.verbose {
            os_log("\(Self.t)🚩 Registering playback observer; playback available=\(playback != nil)")
        }
        viewModel.applyExternalPlayback(url: playback?.currentURL)
        handle = playback?.addObserver { [weak self] event in
            guard case .assetChanged(let url) = event else { return }
            if Self.verbose {
                os_log("\(Self.t)📥 Received assetChanged event: \(url?.path ?? "nil")")
            }
            self?.viewModel?.applyExternalPlayback(url: url)
        }
        if Self.verbose {
            os_log("\(Self.t)✅ Playback observer registration completed")
        }
    }

    func cancel() {
        if Self.verbose {
            os_log("\(Self.t)🛑 Cancelling playback observer")
        }
        handle?.cancel()
        handle = nil
    }
}
