import Combine
import ProviderAudioLibrary
import SwiftUI

/// 根布局状态容器：插件贡献区（工具栏 / 状态区）与播放封面呈现态。
@MainActor
final class RootLayoutViewModel: ObservableObject {
    /// 插件贡献能力（Capabilities 目录收窄）。
    ///
    /// **强持有**：贡献能力由 View 在创建本容器时组装，本容器是它唯一的所有者
    /// （生命周期 = 视图生命周期，短于内核），因此强持有不会延长 Provider 生命周期。
    private let contributions: (any RootContributionCapability)?
    private var contributionHandle: (any RootContributionObserverHandle)?
    @Published private(set) var contributionRevision = 0

    /// 播放器区是否处于「呈现内容」态（有当前曲目，或呈现 idle 占位）。
    ///
    /// 由播放/场景/仓库事件驱动，用于控制控制区高度（收起 150 / 展开 250）。
    /// 之前该状态依赖 `PlaybackHeroVisibilityKey` preference 从插件注入的
    /// Hero 视图跨多层传到根布局，实测该链路不可靠（preference 停留在默认值，
    /// 收起断言恒失败）；按项目的 Observer 架构规范改为事件直达。
    @Published private(set) var isPlaybackHeroPresenting = false

    private var environmentHandle: (any RootEnvironmentObserverHandle)?
    private var hasCurrentAsset = false
    private var isRepositoryEmpty = false
    private var isMusicSceneActive = true
    /// 仓库是否**确认非空**（与「确认为空」互斥）。
    private var isRepositoryKnownNonEmpty = false

    init(contributions: (any RootContributionCapability)?) {
        self.contributions = contributions
    }

    /// 绑定播放环境并建立订阅。
    ///
    /// 必须延迟到内核启动完成（视图 onAppear）后调用：环境中的 Provider 由
    /// 插件在 onBoot/onReady 注册，内核贡献聚合期间调用 `resolveProvider` 会卡死。
    /// 能力 Adapter 由 View 在调用时组装并传入，本容器不触碰任何 Provider。
    func attach(environment: any RootEnvironmentCapability) {
        guard environmentHandle == nil else { return }
        hasCurrentAsset = environment.currentURL != nil
        if let scene = environment.currentScene {
            isMusicSceneActive = scene == .music
        }
        applyRepositoryScanState(environment.repositoryScanState)
        recomputeHeroVisibility()

        environmentHandle = environment.addObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .assetChanged(let url):
                self.hasCurrentAsset = url != nil
                self.recomputeHeroVisibility()
            case .sceneChanged(let scene):
                self.isMusicSceneActive = (scene == .music)
                self.recomputeHeroVisibility()
            case .repositoryEmpty:
                self.isRepositoryEmpty = true
                self.isRepositoryKnownNonEmpty = false
                self.recomputeHeroVisibility()
            case .repositoryNonEmpty:
                self.isRepositoryEmpty = false
                self.isRepositoryKnownNonEmpty = true
                self.recomputeHeroVisibility()
            }
        }
    }

    var toolbarButtons: [(id: String, view: AnyView)] {
        _ = contributionRevision
        return contributions?.getToolBarButtons() ?? []
    }

    var statusViews: [AnyView] {
        _ = contributionRevision
        return contributions?.getStatusViews() ?? []
    }

    /// 应用仓库的扫描结论（三态）。
    ///
    /// 「确认为空」与「确认非空」互斥；「还没扫过」时不下结论——
    /// 此时若按「非空」处理，idle 占位会在启动瞬间抢跑并闪一下。
    private func applyRepositoryScanState(_ state: AudioRepositoryScanState) {
        switch state {
        case .unknown:
            break
        case .empty:
            isRepositoryEmpty = true
            isRepositoryKnownNonEmpty = false
        case .nonEmpty:
            isRepositoryEmpty = false
            isRepositoryKnownNonEmpty = true
        }
    }

    /// 与 `PlaybackHeroViewModel.isHeroVisible` / `showsIdlePlaceholder` 对齐的呈现条件。
    ///
    /// 两种「呈现」都需要控制区留出高度：
    /// - 真实封面：有当前曲目，且（音乐场景下）仓库非空；
    /// - idle 占位：无当前曲目，但仓库**确认非空**（仓库有歌，用户还没选）。
    ///
    /// 仓库为空时两者都不呈现——那块区域归空仓库引导管。
    private func recomputeHeroVisibility() {
        // 真实封面的原有语义保持不变。
        let hasRealHero = hasCurrentAsset && !(isMusicSceneActive && isRepositoryEmpty)
        // idle 占位只出现在音乐场景，且必须「仓库确认非空」。
        let hasIdlePlaceholder = isMusicSceneActive && !hasCurrentAsset && isRepositoryKnownNonEmpty
        isPlaybackHeroPresenting = hasRealHero || hasIdlePlaceholder
    }

    func start() {
        guard contributionHandle == nil else { return }
        contributionHandle = contributions?.addObserver { [weak self] event in
            guard case .contributionsChanged = event else { return }
            self?.contributionRevision &+= 1
        }
    }

    func cancel() {
        contributionHandle?.cancel()
        contributionHandle = nil
        environmentHandle?.cancel()
        environmentHandle = nil
    }
}
