import Foundation
import MagicKit
import OSLog
import ProviderScene

/// 场景观察者：订阅 `SceneProviding` 的场景切换事件，驱动书籍控制的
/// 激活 / 停用（`BookControlViewModel.handleSceneChange`）。
@MainActor
final class BookControlSceneObserver: SuperLog {
    nonisolated static let emoji = "📖"
    nonisolated static let verbose = false

    private weak var viewModel: BookControlViewModel?
    private var sceneHandle: (any SceneProvidingObserverHandle)?

    init(scene: any SceneProviding, viewModel: BookControlViewModel) {
        self.viewModel = viewModel
        if Self.verbose { os_log("\(Self.t)👀 BookControlSceneObserver 初始化") }
        // Initial sync：先同步当前快照再安装监听，避免丢失监听安装前的状态。
        viewModel.handleSceneChange(scene.currentScene)
        sceneHandle = scene.addObserver { [weak self] event in
            guard case let .selectionChanged(scene) = event else { return }
            self?.viewModel?.handleSceneChange(scene)
        }
    }

    func cancel() {
        if Self.verbose {
            os_log("\(Self.t)🧹 BookControlSceneObserver 取消")
        }
        sceneHandle?.cancel()
        sceneHandle = nil
    }
}
