import MagicPlayMan
import MagicKit

@MainActor
final class AudioPlayModeObserver: SuperLog {
    nonisolated static let emoji = "🔀"
    nonisolated static let verbose = false

    private weak var viewModel: AudioPlayModeViewModel?
    private var sceneHandle: (any AudioPlayModeSceneObserverHandle)?
    private var playbackHandle: (any AudioPlayModeObserverHandle)?

    init(
        scene: any AudioPlayModeSceneCapability,
        playback: any AudioPlayModeCapability,
        viewModel: AudioPlayModeViewModel
    ) {
        self.viewModel = viewModel
        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.viewModel?.handleSceneChange(newScene)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard case let .playModeChanged(mode) = event else { return }
            self?.viewModel?.applyPlayModeChanged(mode)
        }
    }

    func cancel() {
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
    }
}
