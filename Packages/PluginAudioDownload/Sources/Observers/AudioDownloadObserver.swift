import MagicKit
import ProviderScene

@MainActor
final class AudioDownloadObserver: SuperLog {
    nonisolated static let emoji = "📥"
    nonisolated static let verbose = false

    private weak var viewModel: AudioDownloadViewModel?
    private var sceneHandle: (any AudioDownloadSceneObserverHandle)?
    private var playbackHandle: (any AudioDownloadObserverHandle)?

    init(
        scene: any AudioDownloadSceneCapability,
        playback: any AudioDownloadCapability,
        viewModel: AudioDownloadViewModel
    ) {
        self.viewModel = viewModel
        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.viewModel?.handleSceneChange(newScene)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard case let .assetChanged(url) = event else { return }
            self?.viewModel?.handleAssetChanged(url)
        }
    }

    func cancel() {
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
    }
}