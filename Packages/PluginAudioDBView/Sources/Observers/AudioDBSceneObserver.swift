import ProviderScene
import MagicKit

/// 场景监听器：订阅 `SceneProviding` 的场景切换事件，驱动 root view 外壳显隐。
///
/// 当场景切离「音乐库」（如切到「有声书」）时，把 `AudioDBSceneState.isMusicScene`
/// 置为 false，`AudioDBPluginRootView` 随之把自己的 root view 外壳下掉、直接
/// 透传内容区；切回音乐库时恢复外壳。
@MainActor
final class AudioDBSceneObserver: SuperLog {
    nonisolated static let emoji = "🎬"
    nonisolated static let verbose = true

    private let sceneState: AudioDBSceneState
    private var handle: (any SceneProvidingObserverHandle)?

    init(scene: (any SceneProviding)?, sceneState: AudioDBSceneState) {
        self.sceneState = sceneState
        self.handle = scene?.addObserver { [weak self] event in
            guard case .selectionChanged(let scene) = event else { return }
            self?.sceneState.isMusicScene = (scene == .music)
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
