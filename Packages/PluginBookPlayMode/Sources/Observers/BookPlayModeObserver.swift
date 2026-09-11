import OSLog
import MagicPlayMan
import ProviderPlayback
import ProviderScene
import MagicKit

@MainActor
final class BookPlayModeObserver: SuperLog {
    nonisolated static let emoji = "🔁"
    nonisolated static let verbose = false

    private weak var viewModel: BookPlayModeViewModel?
    private var sceneHandle: (any SceneProvidingObserverHandle)?
    private var playbackHandle: (any PlaybackProvidingObserverHandle)?

    init(scene: any SceneProviding, playback: any PlaybackProviding, viewModel: BookPlayModeViewModel) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookPlayModeObserver 初始化") }
        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            self?.viewModel?.handleSceneChange(scene)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard case .playModeChanged(let mode) = event else { return }
            self?.viewModel?.handlePlayModeChanged(
                MagicPlayMode(rawValue: mode.rawValue) ?? .sequence
            )
        }
    }

    func cancel() {
        if Self.verbose { os_log("\(Self.t)🧹 BookPlayModeObserver 取消") }
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
    }
}
