import Foundation
import ProviderPlayback
import MagicKit

@MainActor
final class OpenButtonObserver: SuperLog {
    nonisolated static let emoji = "📂"
    nonisolated static let verbose = false

    private weak var viewModel: OpenButtonViewModel?
    private var handle: (any PlaybackProvidingObserverHandle)?

    init(playback: any PlaybackProviding, viewModel: OpenButtonViewModel) {
        self.viewModel = viewModel
        handle = playback.addObserver { [weak self] event in
            guard case .assetChanged(let url) = event else { return }
            self?.viewModel?.handleAssetChanged(url)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
