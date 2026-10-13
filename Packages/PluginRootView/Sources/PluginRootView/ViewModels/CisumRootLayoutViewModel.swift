import Combine
import SwiftUI

/// 根布局状态容器：插件贡献区（工具栏 / 状态区）与播放封面呈现态。
@MainActor
final class CisumRootLayoutViewModel: ObservableObject {
    /// 插件贡献能力（Capabilities 目录收窄）。
    ///
    /// **强持有**：贡献能力由 View 在创建本容器时组装，本容器是它唯一的所有者
    /// （生命周期 = 视图生命周期，短于内核），因此强持有不会延长 Provider 生命周期。
    private let contributions: (any RootContributionCapability)?
    private var contributionHandle: (any RootContributionObserverHandle)?
    @Published private(set) var contributionRevision = 0

    /// 播放器区是否处于「呈现内容」态（有当前曲目，且音乐场景仓库非空）。
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
                self.recomputeHeroVisibility()
            case .repositoryNonEmpty:
                self.isRepositoryEmpty = false
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

    /// 与 `PlaybackHeroViewModel.isHeroVisible` 相同的呈现条件。
    private func recomputeHeroVisibility() {
        isPlaybackHeroPresenting = hasCurrentAsset && !(isMusicSceneActive && isRepositoryEmpty)
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