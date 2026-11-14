import Foundation
import ProviderAppState
import ProviderRootView
import Testing
@testable import FactoryCisum

/// `ContentViewVisibilityCoordinator` 的回归。
///
/// 背景：iOS 上曾出现「打开 App 只剩播放控制区、没有音乐库」的界面。
/// 根因是内容区显隐存在两个互不相通的真源（落盘的 `AppStateProviding`
/// 与纯内存的 `RootViewProviding`），两者之间只有启动时一条单向通路。
/// 后果有三类，本文件逐一锁定：
/// 1. 收起内容区不落盘 → 重启后用户的显式选择丢失；
/// 2. 真源变更没有投影到根视图 → 「打开音乐库」这类入口点了没反应；
/// 3. 内存态与落盘态分叉时按落盘态取反 → 「更多」按钮点了没反应。
@Suite @MainActor
struct ContentViewVisibilityCoordinatorTests {
    /// 内容区显隐的持久化键（与 `BasicAppStateService` 一致）。
    private static let visibilityKey = "UI.ContentViewVisible"

    /// 独立偏好存储，避免污染真实用户偏好。
    private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "ContentViewVisibilityCoordinatorTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    // MARK: - 启动投影

    @Test("启动时把落盘态投影到根视图")
    func startProjectsPersistedVisibilityOntoRoot() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: Self.visibilityKey)

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()

        #expect(!root.isContentViewVisible)
    }

    @Test("启动时真源为可见则根视图可见")
    func startProjectsVisibleStateOntoRoot() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()

        #expect(root.isContentViewVisible)
    }

    // MARK: - 真源 → 根视图投影

    @Test("真源变更必须投影到根视图：否则「打开音乐库」这类入口点了没反应")
    func appStateChangeIsProjectedOntoRoot() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()

        service.hideDBView()
        #expect(!root.isContentViewVisible)

        service.showDBView()
        #expect(root.isContentViewVisible)
    }

    @Test("停止同步后不再投影")
    func stopStopsProjection() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()
        coordinator.stop()

        service.hideDBView()

        #expect(root.isContentViewVisible)
    }

    // MARK: - 用户显式操作

    @Test("「更多」按钮收起内容区必须落盘：否则重启后用户的显式选择丢失")
    func toggleHidesContentAndPersistsTheChoice() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()

        coordinator.toggleContentView()

        #expect(!root.isContentViewVisible)
        #expect(!service.isDBViewVisible)
        #expect(defaults.object(forKey: Self.visibilityKey) as? Bool == false)
    }

    @Test("「更多」按钮展开内容区必须落盘为可见")
    func toggleShowsContentAndPersistsTheChoice() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: Self.visibilityKey)

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()

        coordinator.toggleContentView()

        #expect(root.isContentViewVisible)
        #expect(service.isDBViewVisible)
        #expect(defaults.object(forKey: Self.visibilityKey) as? Bool == true)
    }

    @Test("显式设置必须同时落盘并立即生效")
    func setVisiblePersistsExplicitChoice() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()

        coordinator.setContentViewVisible(false)
        #expect(!root.isContentViewVisible)
        #expect(defaults.object(forKey: Self.visibilityKey) as? Bool == false)

        coordinator.setContentViewVisible(true)
        #expect(root.isContentViewVisible)
        #expect(defaults.object(forKey: Self.visibilityKey) as? Bool == true)
    }

    // MARK: - 内存态 / 落盘态分叉

    @Test("内存态被外部收起时，「更多」按钮仍能带回内容区（不得点了没反应）")
    func toggleRestoresContentHiddenOutsideAppState() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()

        // 桌面端「窗口太矮自动收起副栏」只改内存态，落盘态仍是可见。
        // 若按落盘态取反，用户点「更多」会得到「点了没反应」。
        root.setContentViewVisible(false)
        #expect(service.isDBViewVisible)

        coordinator.toggleContentView()

        #expect(root.isContentViewVisible)
        // 落盘态本来就是可见，不该被这次操作改写。
        #expect(service.isDBViewVisible)
    }

    @Test("落盘态为隐藏时，「更多」按钮收起内容区不得被内存态带偏")
    func toggleHidesContentWhenPersistedStateIsHidden() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: Self.visibilityKey)

        let service = BasicAppStateService(defaults: defaults)
        let root = DefaultRootViewProviding()
        let coordinator = ContentViewVisibilityCoordinator(appState: service, root: root)
        coordinator.start()
        #expect(!root.isContentViewVisible)

        // 内存态被外部展示出来（落盘态仍是隐藏）：点「更多」应按实际可见性收起。
        root.setContentViewVisible(true)
        coordinator.toggleContentView()

        #expect(!root.isContentViewVisible)
        #expect(!service.isDBViewVisible)
    }

    // MARK: - 内核装配

    /// 集成：内核装配后必须能解析到显隐服务，否则插件的「更多」按钮会静默失效。
    ///
    /// 只断言一致性与可解析性，不做切换——切换会写 `.standard` 偏好，
    /// 污染开发机上的真实设置。
    @Test("内核装配后必须能解析到显隐服务，且与真源初始态一致")
    func kernelRegistersContentVisibilityService() async throws {
        let kernel = try await CisumBuilder.createKernel()
        let service = try #require(kernel.resolveProvider((any ContentViewVisibilityProviding).self))
        let appState = try #require(kernel.resolveProvider((any AppStateProviding).self))

        #expect(service.isContentViewVisible == appState.isDBViewVisible)

        try await kernel.stopAsync()
        CisumBuilder.destroyKernel(kernel)
    }
}
