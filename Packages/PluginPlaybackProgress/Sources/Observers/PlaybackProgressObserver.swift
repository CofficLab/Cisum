import MagicKit

/// 播放进度观察者：订阅进度能力并更新插件 ViewModel。
@MainActor
final class PlaybackProgressObserver: SuperLog {
    nonisolated static let emoji = "⏱️"
    nonisolated static let verbose = false

    private weak var viewModel: PlaybackProgressViewModel?
    private var handle: (any ProgressBarObserverHandle)?

    init(playback: any ProgressBarCapability, viewModel: PlaybackProgressViewModel) {
        self.viewModel = viewModel
        handle = playback.addObserver { [weak self] event in
            switch event {
            case .timeChanged(let currentTime):
                self?.viewModel?.handleTimeChanged(currentTime)
            case .durationChanged(let duration):
                self?.viewModel?.handleDurationChanged(duration)
            case .assetChanged:
                self?.viewModel?.handleAssetChanged()
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}