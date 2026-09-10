import Foundation
import ProviderPlayback
import ProviderScene
import MagicKit

/// 音频进度的数据库删除与存储重置观察者（迁移 Phase 5）。
///
/// 订阅 `.dbDeleted` 与指定的存储重置通知，转发到
/// `AudioProgressViewModel`；取代原 `AudioProgressRootView` 的
/// `.onReceive` 与 `AudioProgressStorageResetModifier`。
@MainActor
final class AudioProgressObserver: SuperLog {
    nonisolated static let emoji = "⏱️"
    nonisolated static let verbose = false

    private weak var viewModel: AudioProgressViewModel?
    private var tokens: [NSObjectProtocol] = []
    private var sceneHandle: (any SceneProvidingObserverHandle)?
    private var playbackHandle: (any PlaybackProvidingObserverHandle)?
    private var currentScene: AppScene?

    init(scene: any SceneProviding, playback: any PlaybackProviding, viewModel: AudioProgressViewModel, storageResetNotifications: [Notification.Name]) {
        self.viewModel = viewModel
        currentScene = scene.currentScene
        viewModel.handleSceneChange(from: nil, to: scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            let previousScene = self?.currentScene
            self?.currentScene = scene
            self?.viewModel?.handleSceneChange(from: previousScene, to: scene)
        }
        playbackHandle = playback.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .stateChanged(let state):
                self.viewModel?.handlePlayManStateChanged(state == .playing)
            case .assetChanged(let url):
                self.viewModel?.handlePlayManAssetChanged(url)
            default:
                break
            }
        }
        let center = NotificationCenter.default

        tokens.append(center.addObserver(forName: .dbDeleted, object: nil, queue: .main) { [weak self] notification in
            let urls = notification.userInfo?["urls"] as? [URL] ?? []
            Task { @MainActor in self?.viewModel?.handleDBDeleted(deletedURLs: urls) }
        })

        for name in storageResetNotifications {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.viewModel?.handleStorageLocationDidReset() }
            })
        }
    }

    func cancel() {
        sceneHandle?.cancel()
        sceneHandle = nil
        playbackHandle?.cancel()
        playbackHandle = nil
        currentScene = nil
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }
}
