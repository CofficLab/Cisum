import CisumUIComponents
import Foundation
import SwiftUI

/// 将 `BuiltinPluginManager` 中的插件 UI 贡献聚合为 Kernel Provider。
///
/// 该服务复用旧版 `PluginVM` 的贡献规则（场景/海报/状态/标签页/工具栏/主题
/// 贡献的收集、主题 sortKey 重写与去重、当前场景持久化与缓存失效），
/// 但把插件发现与视图消费边界放到 Kernel，使 Factory 与具体 App 布局
/// 无需直接依赖插件注册表。
///
/// 场景管理（场景列表/当前场景/切换与持久化）已独立到 `PluginScene` 的
/// `SceneProvider`（`SceneProviding`）；场景相关视图由插件自行从 Kernel
/// 解析场景能力并注入所需状态。
@MainActor
public final class PluginContributionService: ObservableObject, PluginProviding {
    private let manager: BuiltinPluginManager

    // MARK: - Caches

    private var cachedStatusViews: [AnyView]?
    private var cachedStateViews: [AnyView]?
    private var cachedPosterViews: [AnyView]?
    private var cachedSettingViews: [AnyView]?
    private var cachedSettingNavItems: [PluginSettingNavigationItem]?
    private var cachedToolBarButtons: [(id: String, view: AnyView)]?
    private var cachedThemeContributions: [LumiUIThemeContribution]?
    private let observers = KernelEventObserverStore<PluginProvidingEvent>()

    public init(manager: BuiltinPluginManager) {
        self.manager = manager
    }

    public var allPlugins: [any SuperPlugin] {
        manager.allPlugins
    }

    public func getStatusViews() -> [AnyView] {
        if let cachedStatusViews { return cachedStatusViews }
        let value = manager.enabledPlugins.compactMap { $0.addStatusView() }
        cachedStatusViews = value
        return value
    }

    public func getStateViews() -> [AnyView] {
        if let cachedStateViews { return cachedStateViews }
        let value = manager.enabledPlugins.compactMap { $0.addStateView() }
        cachedStateViews = value
        return value
    }

    public func getPosterViews() -> [AnyView] {
        if let cachedPosterViews { return cachedPosterViews }
        let value = manager.enabledPlugins.compactMap { $0.addPosterView() }
        cachedPosterViews = value
        return value
    }

    public func getGuideView() -> AnyView? {
        for plugin in manager.enabledPlugins {
            if let view = plugin.addGuideView() { return view }
        }
        return nil
    }

    public func getSettingViews() -> [AnyView] {
        if let cachedSettingViews { return cachedSettingViews }
        let value = manager.enabledPlugins.compactMap { $0.addSettingView() }
        cachedSettingViews = value
        return value
    }

    public func getSettingNavigationItems() -> [PluginSettingNavigationItem] {
        if let cachedSettingNavItems { return cachedSettingNavItems }
        // 对齐 Lumi `SettingEntryItem.order` 语义：按导航项自身 order 排序，
        // 允许插件在导航项中指定独立顺序（如「外观」紧跟「通用」排第 2）。
        let value = manager.enabledPlugins
            .compactMap { $0.addSettingNavigationItem() }
            .sorted { $0.order < $1.order }
        cachedSettingNavItems = value
        return value
    }

    public func getTabViews(reason: String, demoMode: Bool) -> [(view: AnyView, label: String)] {
        manager.enabledPlugins.compactMap { plugin in
            plugin.addTabView(
                reason: reason,
                demoMode: demoMode
            )
        }
    }

    public func wrapWithCurrentRoot<Content: View>(@ViewBuilder content: () -> Content) -> AnyView? {
        var wrapped = AnyView(content())

        for plugin in manager.enabledPlugins {
            wrapped = plugin.wrapRoot(wrapped)
        }

        return wrapped
    }

    public func getToolBarButtons() -> [(id: String, view: AnyView)] {
        if let cachedToolBarButtons { return cachedToolBarButtons }
        let value = manager.enabledPlugins.flatMap { $0.addToolBarButtons() }
        cachedToolBarButtons = value
        return value
    }

    /// 聚合所有主题贡献，按插件 `order` 重写 `sortKey`，按 `id` 去重并排序。
    ///
    /// 与旧版 `PluginVM.getThemeContributions()` 行为一致。
    public func getThemeContributions() -> [LumiUIThemeContribution] {
        if let cachedThemeContributions { return cachedThemeContributions }

        var seen = Set<String>()
        let value: [LumiUIThemeContribution] = manager.enabledPlugins
            .sorted { type(of: $0).metadata.order < type(of: $1).metadata.order }
            .flatMap { plugin -> [LumiUIThemeContribution] in
                let order = type(of: plugin).metadata.order
                return plugin.addThemeContributions().compactMap { contribution in
                    guard seen.insert(contribution.id).inserted else { return nil }
                    return LumiUIThemeContribution(
                        sortKey: ThemeSortKey(pluginOrder: order, themeId: contribution.id),
                        chromeTheme: contribution.chromeTheme,
                        editorThemeId: contribution.id,
                        uiTheme: contribution.uiTheme
                    )
                }
            }

        cachedThemeContributions = value
        return value
    }

    /// 播放控制区封面区为单槽位贡献，取首个启用插件提供的视图。
    public func getHeroView() -> AnyView? {
        for plugin in manager.enabledPlugins {
            if let view = plugin.addHeroView() { return view }
        }
        return nil
    }

    /// 播放控制区右侧封面为单槽位贡献，取首个启用插件提供的视图。
    public func getRightAlbumView() -> AnyView? {
        for plugin in manager.enabledPlugins {
            if let view = plugin.addRightAlbumView() { return view }
        }
        return nil
    }

    /// 播放控制区按钮组为单槽位贡献，取首个启用插件提供的视图。
    public func getControlButtonsView() -> AnyView? {
        for plugin in manager.enabledPlugins {
            if let view = plugin.addControlButtonsView() { return view }
        }
        return nil
    }

    /// 播放控制区进度条为单槽位贡献，取首个启用插件提供的视图。
    public func getProgressView() -> AnyView? {
        for plugin in manager.enabledPlugins {
            if let view = plugin.addProgressView() { return view }
        }
        return nil
    }

    public func invalidateCaches() {
        cachedStatusViews = nil
        cachedStateViews = nil
        cachedPosterViews = nil
        cachedSettingViews = nil
        cachedSettingNavItems = nil
        cachedToolBarButtons = nil
        cachedThemeContributions = nil
        objectWillChange.send()
        observers.send(.contributionsChanged)
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (PluginProvidingEvent) -> Void
    ) -> any PluginProvidingObserverHandle {
        observers.add(callback)
    }
}
