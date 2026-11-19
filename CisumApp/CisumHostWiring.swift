import KernelCore
import ProviderAppState
import ProviderContentView
import ProviderControlView
import ProviderPlugin
import ProviderPluginManaging
import ProviderRootView
import ProviderScene
import SwiftUI

/// 启动完成后的 App 域接线（`HostManifest.wireKernel` 钩子）。
///
/// 原 `FactoryCisum.assembleMainView` 的写入部分 + 显隐协调 + 事件订阅。
/// 主视图本身是纯读取（`RootViewProviding.makeRootView()`），由装配引擎
/// 在视图初始化期组装；这里只负责把插件贡献注入各区域 Provider。
///
/// Provider 的贡献字段是 `@Published`：插件启停 / 场景切换后重新注入，
/// 视图自动跟随，不需要整棵根视图重建。
@MainActor
enum CisumHostWiring {
    private static var pluginHandles: [ObjectIdentifier: any PluginManagingObserverHandle] = [:]
    private static var sceneHandles: [ObjectIdentifier: any SceneProvidingObserverHandle] = [:]
    private static var visibilityCoordinators: [ObjectIdentifier: ContentViewVisibilityCoordinator] = [:]

    static func wire(_ kernel: KernelCoreContainer) {
        injectViews(in: kernel)

        // 内容区显隐由协调器统一：AppState 是唯一真源（只有用户显式操作
        // 才写它），根视图是它的投影。历史上的双向割裂会造成「冷启动只剩
        // 空播放器」与「更多按钮点了没反应」。
        if let appState = kernel.resolveProvider((any AppStateProviding).self),
           let root = kernel.resolveProvider((any RootViewProviding).self) {
            let visibility = ContentViewVisibilityCoordinator(appState: appState, root: root)
            visibility.start()
            try? kernel.registerProvider((any ContentViewVisibilityProviding).self, visibility)
            visibilityCoordinators[ObjectIdentifier(kernel)] = visibility
        }

        // 插件启用/禁用：失效贡献缓存并重新注入视图。
        let pluginHandle = kernel.resolveProvider((any PluginManaging).self)?.addPluginObserver { [weak kernel] event in
            guard case .enabledStateChanged = event, let kernel else { return }
            kernel.resolveProvider((any PluginProviding).self)?.invalidateCaches()
            injectViews(in: kernel)
        }
        if let pluginHandle {
            pluginHandles[ObjectIdentifier(kernel)] = pluginHandle
        }

        // 场景切换：内容 Tab 与控制区贡献按当前场景守卫，切换后重新聚合注入。
        let sceneHandle = kernel.resolveProvider((any SceneProviding).self)?.addObserver { [weak kernel] event in
            guard case .selectionChanged = event, let kernel else { return }
            injectViews(in: kernel)
        }
        if let sceneHandle {
            sceneHandles[ObjectIdentifier(kernel)] = sceneHandle
        }
    }

    /// 释放接线期登记的观察者与协调器（内核销毁时调用）。
    static func release(_ kernel: KernelCoreContainer) {
        let id = ObjectIdentifier(kernel)
        pluginHandles.removeValue(forKey: id)?.cancel()
        sceneHandles.removeValue(forKey: id)?.cancel()
        visibilityCoordinators.removeValue(forKey: id)?.stop()
    }

    /// 把插件贡献的控制区 / 内容区视图注入各区域 Provider，并接到根视图。
    ///
    /// 装配期调用一次；插件启停与场景切换后重调。写入发生在装配期或
    /// 观察者回调里，不在 SwiftUI body 求值期——否则触发
    /// "Publishing changes from within view updates"。
    private static func injectViews(in kernel: KernelCoreContainer) {
        let contributions = kernel.resolveProvider((any PluginProviding).self)
        let demoMode = kernel.resolveProvider((any AppStateProviding).self)?.isDemoMode ?? false
        guard let root = kernel.resolveProvider((any RootViewProviding).self) else { return }

        if let control = kernel.resolveProvider((any ControlViewProviding).self) {
            control.setDemoMode(demoMode)
            control.setHeroView(contributions?.getHeroView())
            control.setRightAlbumView(contributions?.getRightAlbumView())
            control.setControlButtonsView(contributions?.getControlButtonsView())
            control.setProgressView(contributions?.getProgressView())
            root.setControlView(control.makeControlView())
        }
        if let content = kernel.resolveProvider((any ContentViewProviding).self) {
            content.setDemoMode(demoMode)
            let tabs = contributions?.getTabViews(reason: "AppTabView", demoMode: demoMode) ?? []
            content.setTabs(
                tabs.enumerated().map { index, tab in
                    ContentTabItem(
                        id: tab.label,
                        title: tab.label,
                        order: index,
                        content: tab.view
                    )
                }
            )
            root.setContentView(content.makeContentView())
        }
    }
}