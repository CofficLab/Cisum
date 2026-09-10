import ProviderPlayback
import MagicKit

/// 播放设置页的播放状态观察者：把播放详情转发给设置页 ViewModel。
@MainActor
final class PlaybackSettingsPlaybackObserver: SuperLog {
    nonisolated static let emoji = "🎶"
    nonisolated static let verbose = false

    private weak var viewModel: PluginPlayBackSettingsViewModel?
    private var handle: (any PlaybackProvidingObserverHandle)?

    init(playback: (any PlaybackProviding)?, viewModel: PluginPlayBackSettingsViewModel) {
        self.viewModel = viewModel
        handle = playback?.addObserver { [weak self] event in
            switch event {
            case .assetChanged(let url):
                self?.viewModel?.handleAssetChanged(url)
            case .stateChanged(let state):
                self?.viewModel?.handleStateChanged(state)
            case .timeChanged(let currentTime, _):
                self?.viewModel?.handleTimeChanged(currentTime)
            case .durationChanged(let duration):
                self?.viewModel?.handleDurationChanged(duration)
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
