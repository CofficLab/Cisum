import MagicKit
import ProviderControlView

/// 空仓库引导的激活观察者。
///
/// 仓库变空 → 点亮引导；仓库恢复非空 → 熄灭。
///
/// 空/非空结论直接读数据层（`GuideLibraryCapability.isRepositoryEmpty`），
/// 本观察者不自己解释计数：数据层知道仓库扫完了没有，没扫过时计数同样是 0，
/// 那是「还不知道」而不是「是空的」。
///
/// 引导属于「音乐仓库」：切到有声书等其它场景时必须熄灭，否则会在错误的
/// 场景里弹出音乐仓库的引导。
@MainActor
final class RepositoryGuideObserver: SuperLog {
    nonisolated static let emoji = "🧭"
    nonisolated static let verbose = false

    private let slot: ControlGuideSlot
    private let library: any GuideLibraryCapability
    private let scene: any GuideSceneCapability
    private var libraryHandle: (any GuideLibraryObserverHandle)?
    private var sceneHandle: (any GuideSceneObserverHandle)?

    init(
        slot: ControlGuideSlot,
        library: any GuideLibraryCapability,
        scene: any GuideSceneCapability
    ) {
        self.slot = slot
        self.library = library
        self.scene = scene

        libraryHandle = library.addObserver { [weak self] _ in
            self?.updateActivation()
        }

        sceneHandle = scene.addObserver { [weak self] event in
            guard case .selectionChanged = event else { return }
            self?.updateActivation()
        }

        updateActivation()
    }

    /// 同步刷新引导的激活态。
    private func updateActivation() {
        slot.isActive = library.isRepositoryEmpty && isMusicSceneActive
    }

    /// 当前是否处于音乐仓库场景。
    ///
    /// 场景尚未恢复（`nil`）时按音乐场景处理：此时正是首启引导的时间点，
    /// 空仓库引导正是用户最需要的。
    private var isMusicSceneActive: Bool {
        let current = scene.currentScene
        return current == nil || current == .music
    }

    func cancel() {
        libraryHandle?.cancel()
        libraryHandle = nil
        sceneHandle?.cancel()
        sceneHandle = nil
        slot.isActive = false
    }
}
