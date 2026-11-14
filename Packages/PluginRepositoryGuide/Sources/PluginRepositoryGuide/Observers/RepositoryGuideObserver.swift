import MagicKit
import ProviderControlView
import ProviderScene

/// 空仓库引导的激活观察者。
///
/// 当前场景的仓库变空 → 点亮引导；仓库恢复非空 → 熄灭。
///
/// 空/非空结论直接读数据层（`GuideLibraryCapability.isRepositoryEmpty`），
/// 本观察者不自己解释计数：数据层知道仓库扫完了没有，没扫过时计数同样是 0，
/// 那是「还不知道」而不是「是空的」。
///
/// 引导跟随当前场景：音乐场景读音乐仓库，有声书场景读书籍仓库。每个分类
/// 为空时都有同样的头部（封面图 + 标题），而不是只有音乐场景才有。
@MainActor
final class RepositoryGuideObserver: SuperLog {
    nonisolated static let emoji = "🧭"
    nonisolated static let verbose = false

    private let slot: ControlGuideSlot
    private let musicLibrary: any GuideLibraryCapability
    private let bookLibrary: any GuideLibraryCapability
    private let scene: any GuideSceneCapability
    private let content: RepositoryGuideContent
    private var musicHandle: (any GuideLibraryObserverHandle)?
    private var bookHandle: (any GuideLibraryObserverHandle)?
    private var sceneHandle: (any GuideSceneObserverHandle)?

    init(
        slot: ControlGuideSlot,
        musicLibrary: any GuideLibraryCapability,
        bookLibrary: any GuideLibraryCapability,
        scene: any GuideSceneCapability,
        content: RepositoryGuideContent
    ) {
        self.slot = slot
        self.musicLibrary = musicLibrary
        self.bookLibrary = bookLibrary
        self.scene = scene
        self.content = content

        musicHandle = musicLibrary.addObserver { [weak self] _ in
            self?.updateActivation()
        }

        bookHandle = bookLibrary.addObserver { [weak self] _ in
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
        let current = scene.currentScene
        content.scene = current
        slot.isActive = isRepositoryEmpty(in: current)
    }

    /// 当前场景对应的仓库是否为空。
    ///
    /// 场景尚未恢复（`nil`）时按音乐场景处理：此时正是首启引导的时间点，
    /// 空仓库引导正是用户最需要的。
    private func isRepositoryEmpty(in scene: AppScene?) -> Bool {
        switch scene {
        case .audiobooks:
            bookLibrary.isRepositoryEmpty
        case .music, .none:
            musicLibrary.isRepositoryEmpty
        }
    }

    func cancel() {
        musicHandle?.cancel()
        musicHandle = nil
        bookHandle?.cancel()
        bookHandle = nil
        sceneHandle?.cancel()
        sceneHandle = nil
        slot.isActive = false
    }
}
