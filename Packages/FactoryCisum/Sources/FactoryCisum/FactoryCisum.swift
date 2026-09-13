import KernelCore
import CisumUIComponents
import Foundation
import MagicKit
import OSLog
import ProviderContentView
import ProviderControlView
import ProviderDocsView
import ProviderRootView
import ProviderScene
import ProviderSettings
import ProviderToast
import SwiftUI

/// Cisum 应用组装工厂（Composition Root）。
///
/// 唯一知道"如何组装应用"的地方：
/// - 内核生命周期管理（创建、启动、销毁）
/// - 基础设施 Provider 注册（AppState / Playback / Theme / Cloud / Device）
/// - 窗口 / 命令工厂方法
///
/// 插件清单由宿主（app target）通过 `FactoryCisumConfiguration` 传入，Factory
/// 本身不依赖任何具体插件。
///
/// ## 核心流程
///
/// ```swift
/// let kernel = try await FactoryCisum.createMainKernel(configuration: config)
///
/// // 内部:
/// CisumKernel()
///   -> initializePlugins(config.plugins)
///   -> 注册基础设施 Provider
///   -> kernel.startup()
///       -> pluginManager.onBoot(kernel:)   // 插件注册 Storage 等服务
///       -> 必需服务校验
///       -> pluginManager.onReady(kernel:)  // 插件桥接 Host / 异步初始化
///       -> registerPluginUIContributions   // 失效缓存 + 主题同步
/// ```
@MainActor
public enum CisumBuilder: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.cisum", category: "factory")
    nonisolated public static let emoji = "🏭"
    nonisolated static let verbose = false

    // MARK: - Kernel Registry

    /// 已创建的内核列表（支持多内核）。
    public private(set) static var kernels: [CisumKernel] = []

    /// 主内核，取内核列表中的首个。
    public static var mainKernel: CisumKernel? { kernels.first }

    // MARK: - Kernel Factory

    /// 创建并启动一个新内核。
    ///
    /// 流程：
    /// 1. 通过 `PluginFactory` 装配插件清单并初始化（默认 `DefaultPluginFactory`
    ///    直接装配 Cisum 全部内置插件；宿主可传 `SelectedPluginFactory` 等
    ///    自定义实现覆盖）
    /// 2. 注册基础设施 Provider（非插件拥有的跨切面服务）
    /// 3. 启动内核（两阶段生命周期 + 服务校验 + 贡献聚合）
    /// 4. 恢复持久化的当前场景
    /// 5. 订阅插件启用/禁用变更
    public static func createKernel(
        configuration: FactoryCisumConfiguration = FactoryCisumConfiguration(),
        pluginFactory: (any PluginFactory)? = nil
    ) async throws -> CisumKernel {
        let kernel = CisumKernel()

        // 1. 通过插件工厂装配插件清单（对齐 Lumi `pluginFactory.makePlugins()`）
        let factory = pluginFactory ?? DefaultPluginFactory()
        kernel.pluginManager.initializePlugins(factory.makePlugins())

        // 2. 注册基础设施 Provider
        let appState = BasicAppStateService()
        try kernel.registerAppStateService(appState)

        let pluginService = PluginContributionService(manager: kernel.pluginManager)
        try kernel.registerPluginService(pluginService)

        // 播放引擎由 PluginPlayBack 插件在 onBoot 阶段创建并注册为 PlaybackProviding。

        let themeService = ThemeService(contributionsProvider: { [weak kernel] in
            kernel?.plugin?.getThemeContributions() ?? []
        })
        try kernel.registerThemeService(themeService)

        try kernel.registerCloudService(CloudService())
        try kernel.registerDeviceService(DeviceService())
        try kernel.registerDocsService(DefaultDocsViewProvider())
        // 提示 Provider 必须在插件 onBoot 前存在；ToastPlugin 随后替换为真实实现。
        let defaultToast = DefaultToastProvider()
        try kernel.registerToastService(defaultToast)
        CisumToastBridge.install(defaultToast)

        // 视图 Provider 也要在插件 onBoot 前注册，供 ToastPlugin 挂载根覆盖层。
        try registerViewProviders(into: kernel)

        // 3. 启动内核（插件 onBoot 注册 Storage 等服务 → 校验 → onReady → 贡献聚合）
        try await kernel.startup()

        // 3.5 视图 Provider 已在启动前注册，确保根覆盖层可以参与 makeRootView。
        kernel.resolveProvider((any RootViewProviding).self)?
            .setContentViewVisible(appState.isDBViewVisible)

        // 4. 订阅插件变更
        subscribeToPluginChanges(kernel: kernel)

        // 5. 订阅场景变更：切换场景后重建内容 Tab
        subscribeToSceneChanges(kernel: kernel)

        kernels.append(kernel)
        if Self.verbose {
            logger.info("\(Self.t)Kernel created and started successfully")
        }
        return kernel
    }

    /// 创建主内核（幂等：首次调用以传入的 configuration 创建，后续调用返回已有实例）。
    public static func createMainKernel(configuration: FactoryCisumConfiguration) async throws -> CisumKernel {
        if let existing = mainKernel {
            if Self.verbose {
                logger.info("\(Self.t)Main kernel already exists, returning existing instance")
            }
            return existing
        }
        return try await createKernel(configuration: configuration)
    }

    /// 销毁指定内核。
    public static func destroyKernel(_ kernel: CisumKernel) {
        kernels.removeAll { $0 === kernel }
    }

    /// 销毁所有内核。
    public static func destroyAllKernels() {
        kernels.removeAll()
    }

    // MARK: - Window Factory

    /// 创建主窗口视图。
    public static func makeMainWindow(configuration: FactoryCisumConfiguration) -> some View {
        WindowMain(configuration: configuration)
    }

    // MARK: - Settings Window Factory

    /// 创建设置窗口视图。
    ///
    /// 设置窗口复用 `createMainKernel` 返回的主内核（幂等，与主窗口共享同一实例）。
    /// 设置窗口 UI 本体在独立的 `ProviderSettings` 包中（只依赖 Provider 契约），
    /// 此处仅做接线：创建内核 → 解析各 Provider → 注入设置窗口。
    public static func makeSettingsWindow(configuration: FactoryCisumConfiguration) -> some View {
        SettingsWindowHost(configuration: configuration)
    }

    // MARK: - Commands Factory

    /// 创建应用命令菜单。
    ///
    /// 命令装配集中在 Factory 包内（对齐 Lumi `FactoryLumi/AppCommands.swift`），
    /// 宿主只需 `.commands { FactoryCisum.makeCommands() }`。
    public static func makeCommands() -> some Commands {
        CisumAppCommands()
    }

    // MARK: - View Assembly

    /// 注册视图 Provider 默认实现（对齐 Lumi `DefaultProviderFactory` 的
    /// `makeXxxProvider()` 方法族）。
    ///
    /// 各视图区域（根布局 / 播放控制区 / 内容区 / 工具栏）是独立的
    /// Provider 契约，默认实现注册进内核；Factory 组装时只做解析 + 注入 +
    /// makeRootView。
    private static func registerViewProviders(into kernel: CisumKernel) throws {
        try kernel.registerProvider((any RootViewProviding).self, DefaultRootViewProvider(kernel: kernel))
        try kernel.registerProvider(
            (any ControlViewProviding).self,
            DefaultControlViewProvider(
                stateViews: { kernel.plugin?.getStateViews() ?? [] },
                stateMessage: { kernel.appState?.stateMessage ?? "" }
            )
        )
        try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProvider())
    }

    /// 组装主视图（对齐 Lumi `DefaultViewFactory.makeMainView(kernel:)`）。
    ///
    /// 视图组装逻辑集中在此：解析 `RootViewProviding` → 注入各区域视图
    /// （播放控制区来自 `ControlViewProviding`、内容区来自 `ContentViewProviding`）→
    /// 返回 `makeRootView()`。工具栏按钮由插件通过 `addToolBarButtons()` 贡献，
    /// 不再经由 `ToolbarProviding` 注入。
    /// 宿主只需要一个视图，无需关心各 Provider 如何组合。
    @MainActor
    public static func assembleMainView(kernel: CisumKernel) -> AnyView {
        guard let root = kernel.resolveProvider((any RootViewProviding).self) else {
            return AnyView(Text("RootViewProviding not registered"))
        }

        if let control = kernel.resolveProvider((any ControlViewProviding).self) {
            control.setDemoMode(kernel.appState?.isDemoMode ?? false)
            control.setHeroView(kernel.plugin?.getHeroView())
            control.setRightAlbumView(kernel.plugin?.getRightAlbumView())
            control.setControlButtonsView(kernel.plugin?.getControlButtonsView())
            control.setProgressView(kernel.plugin?.getProgressView())
            root.setControlView(control.makeControlView())
        }
        if let content = kernel.resolveProvider((any ContentViewProviding).self) {
            content.setDemoMode(kernel.appState?.isDemoMode ?? false)
            refreshContentTabs(content, kernel: kernel)
            root.setContentView(content.makeContentView())
        }
        return root.makeRootView()
    }

    /// 把插件贡献的内容 Tab 注入 `ContentViewProviding`。
    ///
    /// 对齐 Lumi 插件通过 Provider 注入内容的范式；Cisum 侧由
    /// `PluginContributionService` 聚合插件贡献，此处转成 `ContentTabItem` 注入。
    @MainActor
    private static func refreshContentTabs(_ content: any ContentViewProviding, kernel: CisumKernel) {
        let contribution = kernel.plugin?.getTabViews(
            reason: "AppTabView",
            demoMode: kernel.appState?.isDemoMode ?? false
        ) ?? []
        content.setTabs(
            contribution.enumerated().map { index, tab in
                ContentTabItem(
                    id: tab.label,
                    title: tab.label,
                    order: index,
                    content: tab.view
                )
            }
        )
    }

    // MARK: - Private

    /// 订阅插件启用/禁用变更通知，触发贡献重建。
    private static func subscribeToPluginChanges(kernel: CisumKernel) {
        NotificationCenter.default.addObserver(
            forName: .cisumEnabledPluginsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                kernel.pluginManager.rebuildAllContributions(in: kernel)
            }
        }
    }

    /// 场景切换后重建内容 Tab。
    ///
    /// 内容 Tab 由各插件按当前场景守卫贡献（`addTabView` 检查
    /// `sceneBox.scene?.currentScene`），启动装配时只组装一次；场景切换不会
    /// 触发重建，导致内容区停留在启动场景的 Tab。此处订阅
    /// `SceneProviding.selectionChanged`，切换后重新聚合注入，使内容区跟随场景。
    private static func subscribeToSceneChanges(kernel: CisumKernel) {
        let handle = kernel.scene?.addObserver { [weak kernel] event in
            guard case .selectionChanged = event else { return }
            Task { @MainActor in
                guard let kernel else { return }
                if let content = kernel.resolveProvider((any ContentViewProviding).self) {
                    refreshContentTabs(content, kernel: kernel)
                }
                NotificationCenter.default.post(name: .cisumSceneDidChange, object: nil)
            }
        }
        sceneObserverHandle = handle
    }

    /// 场景监听句柄（跨方法存活，避免 `SceneProvider` 弱引用提前释放监听器）。
    private nonisolated(unsafe) static var sceneObserverHandle: (any SceneProvidingObserverHandle)?
}

/// 兼容别名。
public typealias FactoryCisum = CisumBuilder
