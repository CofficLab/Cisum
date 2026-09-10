import ProviderPlayback
import MagicKit

/// 播放封面观察者：订阅 `PlaybackProviding` 并驱动封面 ViewModel。
@MainActor
final class PlaybackHeroObserver: SuperLog {
    nonisolated static let emoji = "🎤"
    nonisolated static let verbose = false

    private weak var viewModel: PlaybackHeroViewModel?
    private var handle: (any PlaybackProvidingObserverHandle)?

    init(playback: (any PlaybackProviding)?, viewModel: PlaybackHeroViewModel) {
        self.viewModel = viewModel
        handle = playback?.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .assetChanged(let url):
                self.viewModel?.applyAssetChanged(url)
            case .stateChanged(let state):
                self.viewModel?.applyStateChanged(state)
            default: break
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
