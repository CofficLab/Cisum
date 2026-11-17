import ProviderPlayback

/// 书籍进度条观察者：订阅进度能力并更新 ViewModel。
@MainActor
final class BookProgressBarObserver {
    private weak var viewModel: BookProgressBarViewModel?
    private var handle: (any BookProgressBarObserverHandle)?

    init(playback: any BookProgressBarCapability, viewModel: BookProgressBarViewModel) {
        self.viewModel = viewModel
        handle = playback.addObserver { [weak self] event in
            switch event {
            case let .timeChanged(currentTime):
                self?.viewModel?.handleTimeChanged(currentTime)
            case let .durationChanged(duration):
                self?.viewModel?.handleDurationChanged(duration)
            case .assetChanged:
                self?.viewModel?.handleAssetChanged()
            case let .stateChanged(state):
                self?.viewModel?.handleStateChanged(state)
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
