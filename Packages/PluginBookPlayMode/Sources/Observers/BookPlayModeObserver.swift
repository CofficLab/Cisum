import Foundation
import OSLog
import MagicKit

@MainActor
final class BookPlayModeObserver: SuperLog {
    nonisolated static let emoji = "🔁"
    nonisolated static let verbose = false

    private weak var viewModel: BookPlayModeViewModel?
    private var sceneHandle: (any BookPlayModeSceneObserverHandle)?
    private var playbackHandle: (any BookPlayModeObserverHandle)?

    init(
        scene: any BookPlayModeSceneCapability,
        playback: any BookPlayModeCapability,
        viewModel: BookPlayModeViewModel
    ) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookPlayModeObserver 初始化") }
        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(newScene) = event else { return }
            self?.viewModel?.handleSceneChange(newScene)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard case let .playModeChanged(mode) = event else { return }
            self?.viewModel?.handlePlayModeChanged(mode)
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