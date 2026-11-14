import Foundation
import MagicKit

@MainActor
final class OpenButtonObserver: SuperLog {
    nonisolated static let emoji = "📂"
    nonisolated static let verbose = false

    private weak var viewModel: OpenButtonViewModel?
    private var handle: (any OpenButtonObserverHandle)?

    init(playback: any OpenButtonCapability, viewModel: OpenButtonViewModel) {
        self.viewModel = viewModel
        handle = playback.addObserver { [weak self] event in
            guard case let .assetChanged(url) = event else { return }
            self?.viewModel?.handleAssetChanged(url)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}