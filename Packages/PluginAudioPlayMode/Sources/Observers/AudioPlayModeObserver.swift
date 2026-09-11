import MagicPlayMan
import ProviderPlayback
import ProviderScene
import MagicKit

@MainActor
final class AudioPlayModeObserver: SuperLog {
    nonisolated static let emoji = "🔀"
    nonisolated static let verbose = false

    private weak var viewModel: AudioPlayModeViewModel?
    private var sceneHandle: (any SceneProvidingObserverHandle)?
    private var playbackHandle: (any PlaybackProvidingObserverHandle)?

    init(scene: any SceneProviding, playback: any PlaybackProviding, viewModel: AudioPlayModeViewModel) {
        self.viewModel = viewModel
        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            self?.viewModel?.handleSceneChange(scene)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard case .playModeChanged(let mode) = event else { return }
                self?.viewModel?.applyPlayModeChanged(
                    MagicPlayMode(rawValue: mode.rawValue) ?? .sequence
                )
        }
    }

    func cancel() {
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
    }
}
