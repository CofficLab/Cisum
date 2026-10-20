import MagicKit
import ProviderControlView

/// 空仓库引导的激活观察者。
///
/// 仓库变空 → 点亮引导；仓库恢复非空 → 熄灭。
///
/// 只认「仓库权威事件」：`repositoryEmpty` 是权威的「确认为空」信号，
/// 其余事件只用来复核计数——Provider 尚未就绪时计数为 0，那不是「仓库为空」，
/// 此时保持现状而不是误点亮引导。
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

    /// 最近一次结论：仓库是否为空。
    private var isRepositoryEmpty = false

    init(
        slot: ControlGuideSlot,
        library: any GuideLibraryCapability,
        scene: any GuideSceneCapability
    ) {
        self.slot = slot
        self.library = library
        self.scene = scene

        libraryHandle = library.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .repositoryEmpty:
                // 权威信号：立刻点亮，不等计数复核。
                isRepositoryEmpty = true
                updateActivation()
            case .changed:
                refreshActivation()
            }
        }

        sceneHandle = scene.addObserver { [weak self] event in
            guard case .selectionChanged = event else { return }
            self?.updateActivation()
        }
    }

    /// 按当前仓库计数复核激活态。
    private func refreshActivation() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard library.isAvailable else { return }
            let count = await library.totalCount()
            isRepositoryEmpty = (count == 0)
            updateActivation()
        }
    }

    /// 同步刷新引导的激活态。
    private func updateActivation() {
        slot.isActive = isRepositoryEmpty && isMusicSceneActive
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
