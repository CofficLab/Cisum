import MagicKit
import os

/// 订阅播放与外部环境事件，并把事件回写给 ViewModel。
@MainActor
final class ControlButtonsObserver: SuperLog {
    nonisolated static let emoji = "🎛️"
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "ControlButtons.Observer")

    private weak var viewModel: ControlButtonsViewModel?
    private var playbackHandle: (any PlaybackControlObserverHandle)?
    private var environmentHandle: (any PlaybackEnvironmentObserverHandle)?

    init(
        playback: any PlaybackControlCapability,
        environment: any PlaybackEnvironmentCapability,
        viewModel: ControlButtonsViewModel
    ) {
        self.viewModel = viewModel
        if Self.verbose {
            Self.log.info("\(Self.t)👀 ControlButtons observer installed; scene=\(String(describing: environment.currentScene))")
        }
        viewModel.handleSceneChange(environment.currentScene)

        playbackHandle = playback.addObserver { [weak self] event in
            guard let self else {
                Self.log.error("\(Self.t)❌ Playback event dropped: ControlButtons observer was released")
                return
            }
            switch event {
            case .stateChanged(let state):
                if Self.verbose {
                    Self.log.info("\(Self.t)📥 Playback state changed: \(String(describing: state))")
                }
                self.viewModel?.applyStateChanged(state)
            case .playModeChanged(let mode):
                if Self.verbose {
                    Self.log.info("\(Self.t)📥 Playback mode changed: \(String(describing: mode))")
                }
                self.viewModel?.applyPlayModeChanged(mode)
            case .previousRequested(let asset):
                if Self.verbose {
                    Self.log.info("\(Self.t)⬅️ Playback emitted previous request: \(asset.lastPathComponent)")
                }
                self.viewModel?.handlePreviousRequested(asset)
            case .nextRequested(let asset):
                if Self.verbose {
                    Self.log.info("\(Self.t)➡️ Playback emitted next request: \(asset.lastPathComponent)")
                }
                self.viewModel?.handleNextRequested(asset)
            case .navigationFailed(let failure):
                Self.log.error("\(Self.t)❌ Playback navigation failed: \(failure.reason)")
                self.viewModel?.handleNavigationFailure(failure)
            }
        }

        environmentHandle = environment.addObserver { [weak self] event in
            guard let self else {
                Self.log.error("\(Self.t)❌ Environment event dropped: observer was released")
                return
            }
            switch event {
            case .sceneChanged(let scene):
                if Self.verbose {
                    Self.log.info("\(Self.t)👀 Scene changed: \(String(describing: scene))")
                }
                self.viewModel?.handleSceneChange(scene)
            case .filesDeleted(let urls):
                self.viewModel?.handleDBDeleted(urlsToDelete: urls)
            case .storageLocationReset:
                self.viewModel?.handleStorageLocationDidReset()
            }
        }
    }

    func cancel() {
        playbackHandle?.cancel()
        playbackHandle = nil
        environmentHandle?.cancel()
        environmentHandle = nil
    }
}