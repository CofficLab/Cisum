import Foundation
import MagicKit
import MagicPlayMan
import ProviderPlayback
import ProviderScene
import os

/// 订阅播放、场景和音频库外部事件，并把事件回写给 ViewModel。
@MainActor
final class ControlButtonsObserver: SuperLog {
    nonisolated static let emoji = "🎛️"
    nonisolated static let verbose = false
    private static let log = Logger(subsystem: "com.yueyi.cisum", category: "ControlButtons.Observer")

    private weak var viewModel: ControlButtonsViewModel?
    private var playbackHandle: (any PlaybackProvidingObserverHandle)?
    private var sceneHandle: (any SceneProvidingObserverHandle)?
    private var notificationTokens: [NSObjectProtocol] = []

    init(scene: any SceneProviding, playback: any PlaybackProviding, viewModel: ControlButtonsViewModel) {
        self.viewModel = viewModel
        if Self.verbose {
            Self.log.info("\(Self.t)👀 ControlButtons observer installed; scene=\(String(describing: scene.currentScene))")
        }
        viewModel.handleSceneChange(scene.currentScene)

        sceneHandle = scene.addObserver { [weak self] event in
            guard let self else {
                Self.log.error("\(Self.t)❌ Scene event dropped: observer was released")
                return
            }
            guard case .selectionChanged(let scene) = event else { return }
            if Self.verbose {
                Self.log.info("\(Self.t)👀 Scene changed: \(String(describing: scene))")
            }
            self.viewModel?.handleSceneChange(scene)
        }

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
                self.viewModel?.applyPlayModeChanged(
                    MagicPlayMode(rawValue: mode.rawValue) ?? .sequence
                )
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
            default:
                break
            }
        }

        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: Notification.Name("dbDeleted"), object: nil, queue: .main) { [weak self] notification in
            let urls = notification.userInfo?["urls"] as? [URL] ?? []
            Task { @MainActor in
                self?.viewModel?.handleDBDeleted(urlsToDelete: urls)
            }
        })
        notificationTokens.append(center.addObserver(forName: Notification.Name("storageLocationDidReset"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.viewModel?.handleStorageLocationDidReset()
            }
        })
    }

    func cancel() {
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        notificationTokens.removeAll()
    }
}
