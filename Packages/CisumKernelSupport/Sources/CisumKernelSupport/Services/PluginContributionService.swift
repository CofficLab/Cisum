import CisumUIComponents
import Foundation
import KernelCore
import SwiftUI

/// 插件 UI 贡献注册表 + 聚合查询 Provider（对齐 Lumi 范式）。
///
/// 插件在 `onBoot` / `onEnable` 时通过 `PluginContributionProviding` 登记
/// 贡献（owner = 内核 `activePluginID`），在 `onShutdown` / `onDisable` 时
/// 按 owner 撤回；宿主 UI 通过 `PluginProviding` 查询聚合结果。
///
/// 聚合规则继承自旧版 `PluginVM`：场景/海报/状态/标签页/工具栏/主题贡献的
/// 收集、主题 sortKey 重写与去重、缓存失效。只有已启用插件的贡献会被返回。
@MainActor
public final class PluginContributionService: ObservableObject,
    PluginProviding,
    PluginContributionProviding
{
    private weak var kernel: KernelCoreContainer?

    // MARK: - Contribution Registry（owner plugin id → contribution）

    private var rootWrappers: [String: @MainActor (AnyView) -> AnyView?] = [:]
    private var guideViews: [String: AnyView] = [:]
    private var stateViews: [String: AnyView] = [:]
    private var posterViews: [String: AnyView] = [:]
    private var tabViews: [String: @MainActor (String, Bool) -> (view: AnyView, label: String)?] = [:]
    private var settingViews: [String: AnyView] = [:]
    private var settingNavItems: [String: PluginSettingNavigationItem] = [:]
    private var toolBarButtons: [String: [(id: String, view: AnyView)]] = [:]
    private var themeContributions: [String: [LumiUIThemeContribution]] = [:]
    private var heroViews: [String: AnyView] = [:]
    private var rightAlbumViews: [String: AnyView] = [:]
    private var controlButtonsViews: [String: AnyView] = [:]
    private var progressViews: [String: AnyView] = [:]

    // MARK: - Caches

    private var cachedStatusViews: [AnyView]?
    private var cachedStateViews: [AnyView]?
    private var cachedPosterViews: [AnyView]?
    private var cachedSettingViews: [AnyView]?
    private var cachedSettingNavItems: [PluginSettingNavigationItem]?
    private var cachedToolBarButtons: [(id: String, view: AnyView)]?
    private var cachedThemeContributions: [LumiUIThemeContribution]?
    private let observers = KernelEventObserverStore<PluginProvidingEvent>()

    public init(kernel: KernelCoreContainer) {
        self.kernel = kernel
    }

    // MARK: - 已启用插件顺序（对齐旧 BuiltinPluginManager.enabledPlugins：按启动顺序）

    /// 按启动顺序返回已启用插件（查询聚合时遍历，保证与旧行为一致的稳定顺序）。
    private var enabledPluginsInOrder: [any SuperPlugin] {
        guard let kernel else { return [] }
        return kernel.allPlugins.filter { kernel.isPluginEnabled(id: $0.id) }
    }

    private var enabledPluginIDs: Set<String> {
        Set(enabledPluginsInOrder.map(\.id))
    }

    /// 当前注册上下文 owner（内核生命周期回调期间为插件 id）。
    private var currentOwner: String? {
        kernel?.activePluginID
    }

    // MARK: - PluginContributionProviding

    public func addRootView(_ contribution: @escaping @MainActor (AnyView) -> AnyView?) {
        guard let owner = currentOwner else { return }
        rootWrappers[owner] = contribution
        invalidateCaches()
    }

    public func addGuideView(_ view: AnyView) {
        guard let owner = currentOwner else { return }
        guideViews[owner] = view
        invalidateCaches()
    }

    public func addStateView(_ view: AnyView) {
        guard let owner = currentOwner else { return }
        stateViews[owner] = view
        invalidateCaches()
    }

    public func addPosterView(_ view: AnyView) {
        guard let owner = currentOwner else { return }
        posterViews[owner] = view
        invalidateCaches()
    }

    public func addTabView(
        _ contribution: @escaping @MainActor (_ reason: String, _ demoMode: Bool) -> (view: AnyView, label: String)?
    ) {
        guard let owner = currentOwner else { return }
        tabViews[owner] = contribution
        invalidateCaches()
    }

    public func addSettingView(_ view: AnyView) {
        guard let owner = currentOwner else { return }
        settingViews[owner] = view
        invalidateCaches()
    }

    public func addSettingNavigationItem(_ item: PluginSettingNavigationItem) {
        guard let owner = currentOwner else { return }
        settingNavItems[owner] = item
        invalidateCaches()
    }

    public func addToolBarButtons(_ buttons: [(id: String, view: AnyView)]) {
        guard let owner = currentOwner else { return }
        toolBarButtons[owner] = buttons
        invalidateCaches()
    }

    public func addThemeContributions(_ contributions: [LumiUIThemeContribution]) {
        guard let owner = currentOwner else { return }
        themeContributions[owner] = contributions
        invalidateCaches()
    }

    public func addHeroView(_ view: AnyView) {
        guard let owner = currentOwner else { return }
        heroViews[owner] = view
        invalidateCaches()
    }

    public func addRightAlbumView(_ view: AnyView) {
        guard let owner = currentOwner else { return }
        rightAlbumViews[owner] = view
        invalidateCaches()
    }

    public func addControlButtonsView(_ view: AnyView) {
        guard let owner = currentOwner else { return }
        controlButtonsViews[owner] = view
        invalidateCaches()
    }

    public func addProgressView(_ view: AnyView) {
        guard let owner = currentOwner else { return }
        progressViews[owner] = view
        invalidateCaches()
    }

    public func remove(owner: String) {
        rootWrappers.removeValue(forKey: owner)
        guideViews.removeValue(forKey: owner)
        stateViews.removeValue(forKey: owner)
        posterViews.removeValue(forKey: owner)
        tabViews.removeValue(forKey: owner)
        settingViews.removeValue(forKey: owner)
        settingNavItems.removeValue(forKey: owner)
        toolBarButtons.removeValue(forKey: owner)
        themeContributions.removeValue(forKey: owner)
        heroViews.removeValue(forKey: owner)
        rightAlbumViews.removeValue(forKey: owner)
        controlButtonsViews.removeValue(forKey: owner)
        progressViews.removeValue(forKey: owner)
        invalidateCaches()
    }

    // MARK: - PluginProviding

    public var allPlugins: [any SuperPlugin] {
        enabledPluginsInOrder
    }

    public func getStatusViews() -> [AnyView] {
        // 旧协议无 addStatusView 实现者（默认 nil）；保留插槽返回空。
        []
    }

    public func getStateViews() -> [AnyView] {
        if let cachedStateViews { return cachedStateViews }
        let value = stateViews
            .filter { enabledPluginIDs.contains($0.key) }
            .sorted { pluginOrder($0.key) < pluginOrder($1.key) }
            .map(\.value)
        cachedStateViews = value
        return value
    }

    public func getPosterViews() -> [AnyView] {
        if let cachedPosterViews { return cachedPosterViews }
        let value = posterViews
            .filter { enabledPluginIDs.contains($0.key) }
            .sorted { pluginOrder($0.key) < pluginOrder($1.key) }
            .map(\.value)
        cachedPosterViews = value
        return value
    }

    public func getGuideView() -> AnyView? {
        for plugin in enabledPluginsInOrder where guideViews[plugin.id] != nil {
            return guideViews[plugin.id]
        }
        return nil
    }

    public func getSettingViews() -> [AnyView] {
        if let cachedSettingViews { return cachedSettingViews }
        let value = settingViews
            .filter { enabledPluginIDs.contains($0.key) }
            .sorted { pluginOrder($0.key) < pluginOrder($1.key) }
            .map(\.value)
        cachedSettingViews = value
        return value
    }

    public func getSettingNavigationItems() -> [PluginSettingNavigationItem] {
        if let cachedSettingNavItems { return cachedSettingNavItems }
        // 对齐 Lumi `SettingEntryItem.order` 语义：按导航项自身 order 排序，
        // 允许插件在导航项中指定独立顺序（如「外观」紧跟「通用」排第 2）。
        let value = settingNavItems
            .filter { enabledPluginIDs.contains($0.key) }
            .map(\.value)
            .sorted { $0.order < $1.order }
        cachedSettingNavItems = value
        return value
    }

    public func getTabViews(reason: String, demoMode: Bool) -> [(view: AnyView, label: String)] {
        enabledPluginsInOrder.compactMap { plugin in
            tabViews[plugin.id]?(reason, demoMode)
        }
    }

    public func wrapWithCurrentRoot<Content: View>(@ViewBuilder content: () -> Content) -> AnyView? {
        var wrapped = AnyView(content())

        for plugin in enabledPluginsInOrder {
            if let wrapper = rootWrappers[plugin.id] {
                if let next = wrapper(wrapped) {
                    wrapped = next
                }
            }
        }

        return wrapped
    }

    public func getToolBarButtons() -> [(id: String, view: AnyView)] {
        if let cachedToolBarButtons { return cachedToolBarButtons }
        let value = toolBarButtons
            .filter { enabledPluginIDs.contains($0.key) }
            .sorted { pluginOrder($0.key) < pluginOrder($1.key) }
            .flatMap(\.value)
        cachedToolBarButtons = value
        return value
    }

    /// 聚合所有主题贡献，按插件 `order` 重写 `sortKey`，按 `id` 去重并排序。
    ///
    /// 与旧版 `PluginVM.getThemeContributions()` 行为一致。
    public func getThemeContributions() -> [LumiUIThemeContribution] {
        if let cachedThemeContributions { return cachedThemeContributions }

        var seen = Set<String>()
        let value: [LumiUIThemeContribution] = enabledPluginsInOrder
            .flatMap { plugin -> [LumiUIThemeContribution] in
                guard let contributions = themeContributions[plugin.id] else { return [] }
                let order = plugin.order
                return contributions.compactMap { contribution in
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
        for plugin in enabledPluginsInOrder where heroViews[plugin.id] != nil {
            return heroViews[plugin.id]
        }
        return nil
    }

    /// 播放控制区右侧封面为单槽位贡献，取首个启用插件提供的视图。
    public func getRightAlbumView() -> AnyView? {
        for plugin in enabledPluginsInOrder where rightAlbumViews[plugin.id] != nil {
            return rightAlbumViews[plugin.id]
        }
        return nil
    }

    /// 播放控制区按钮组为单槽位贡献，取首个启用插件提供的视图。
    public func getControlButtonsView() -> AnyView? {
        for plugin in enabledPluginsInOrder where controlButtonsViews[plugin.id] != nil {
            return controlButtonsViews[plugin.id]
        }
        return nil
    }

    /// 播放控制区进度条为单槽位贡献，取首个启用插件提供的视图。
    public func getProgressView() -> AnyView? {
        for plugin in enabledPluginsInOrder where progressViews[plugin.id] != nil {
            return progressViews[plugin.id]
        }
        return nil
    }

    public func invalidateCaches() {
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

    // MARK: - Private

    private func pluginOrder(_ owner: String) -> Int {
        guard let kernel, let plugin = kernel.resolvePlugin(id: owner) else { return 9999 }
        return plugin.order
    }
}
