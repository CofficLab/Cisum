import ProviderScene
import MagicKit

/// 场景设置与切换视图需要的最小场景能力。
///
/// ViewModel 不直接持有 `SceneProviding`；Provider 由 `ScenePlugin` 适配后注入。
@MainActor
protocol SceneSettingsCapability: AnyObject {
    var scenes: [AppScene] { get }
    var currentScene: AppScene? { get }

    func setCurrentScene(_ scene: AppScene)
}

/// 将内核场景 Provider 收窄成设置与切换视图所需的能力。
@MainActor
final class SceneSettingsCapabilityAdapter: SceneSettingsCapability, SuperLog {
    nonisolated static let verbose = false

    private weak var scene: (any SceneProviding)?

    init(scene: any SceneProviding) {
        self.scene = scene
    }

    var scenes: [AppScene] { scene?.scenes ?? [] }
    var currentScene: AppScene? { scene?.currentScene }

    func setCurrentScene(_ scene: AppScene) {
        self.scene?.setCurrentScene(scene)
    }
}