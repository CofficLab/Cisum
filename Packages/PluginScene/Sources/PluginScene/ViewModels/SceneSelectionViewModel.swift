import Combine
import Foundation
import ProviderScene
import MagicKit

/// 场景选择的状态容器：维护可选场景列表与当前选中项。
///
/// 通过 `SceneSelectionCapability` 读写场景（见 Capabilities 目录），
/// 不直接持有内核 `SceneProviding`：
/// - 「Provider 未就绪」与「已就绪但场景为空」是两种不同状态，
///   前者 `scenes` / `currentScene` 返回空值并在 UI 上隐藏整个区块；
@MainActor
final class SceneSelectionViewModel: ObservableObject, SuperLog {
    nonisolated static let verbose = false

    @Published private(set) var revision = 0

    /// 场景能力（Capabilities 目录收窄），`weak` 持有。
    private weak var selection: (any SceneSelectionCapability)?
    private var currentScenes: [AppScene] = []
    private var selectedScene: AppScene?

    init(selection: (any SceneSelectionCapability)?) {
        self.selection = selection
        refresh()
    }

    /// 场景能力是否已绑定到内核 Provider；未就绪时视图应隐藏场景区块。
    var isAvailable: Bool { selection?.isAvailable ?? false }

    var scenes: [AppScene] { isAvailable ? currentScenes : [] }
    var currentScene: AppScene? { isAvailable ? selectedScene : nil }

    /// 用户意图：切换到指定场景。
    func select(_ target: AppScene) {
        selection?.setCurrentScene(target)
        refresh()
    }

    func handleSelectionChanged() {
        refresh()
    }

    /// 重新绑定场景能力：`onBoot` 阶段创建的 ViewModel 可能早于场景 Provider
    /// 注册，`onReady` 会带着已就绪的能力再绑定一次。
    func bind(selection: (any SceneSelectionCapability)?) {
        self.selection = selection
        refresh()
    }

    private func refresh() {
        currentScenes = selection?.scenes ?? []
        selectedScene = selection?.currentScene
        revision &+= 1
    }
}
