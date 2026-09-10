import ProviderPlayback
import MagicKit

/// 播放进度观察者：订阅 `PlaybackProviding` 并更新插件 ViewModel。
@MainActor
final class PlaybackProgressObserver: SuperLog {
    nonisolated static let emoji = "⏱️"
    nonisolated static let verbose = false

    private weak var viewModel: PlaybackProgressViewModel?
    private var handle: (any PlaybackProvidingObserverHandle)?

    init(playback: (any PlaybackProviding)?, viewModel: PlaybackProgressViewModel) {
        self.viewModel = viewModel
        handle = playback?.addObserver { [weak self] event in
            switch event {
            case .timeChanged(let currentTime, _):
                self?.viewModel?.handleTimeChanged(currentTime)
            case .durationChanged(let duration):
                self?.viewModel?.handleDurationChanged(duration)
            case .assetChanged:
                self?.viewModel?.handleAssetChanged()
            default:
                break
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
