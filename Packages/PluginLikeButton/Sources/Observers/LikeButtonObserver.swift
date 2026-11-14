import Foundation
import MagicKit

@MainActor
final class LikeButtonObserver: SuperLog {
    nonisolated static let emoji = "👍"
    nonisolated static let verbose = false

    private weak var viewModel: LikeButtonViewModel?
    private var handle: (any LikeButtonObserverHandle)?

    init(playback: any LikeButtonCapability, viewModel: LikeButtonViewModel) {
        self.viewModel = viewModel
        handle = playback.addObserver { [weak self] event in
            switch event {
            case .assetChanged(let url):
                self?.viewModel?.handleAssetChanged(url)
            case .likeStatusChanged(let liked):
                self?.viewModel?.handleLikeStatusChanged(liked)
            case .likedAssetsChanged(let assets):
                self?.viewModel?.handleLikedAssetsChanged(assets)
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
