import CisumUIComponents
import LumiUI
import SwiftUI

/// 插件 UI 贡献注册协议（对齐 Lumi 范式）。
///
/// 插件的 UI 贡献不再挂在插件协议上，而是在 `onBoot` / `onEnable` 阶段通过
/// 本协议登记到贡献注册表（实现：`PluginContributionService`），并在
/// `onShutdown` / `onDisable` 时按 `owner`（插件 id）撤回。宿主 UI 通过
/// `PluginProviding` 查询聚合结果。
///
/// 每项贡献显式携带插件 ID，由提供者按 owner 聚合，并在插件关闭时撤回。
@MainActor
public protocol PluginContributionProviding: AnyObject {
    /// 登记根视图包裹函数（返回 `AnyView?`，nil 表示不包裹）。
    func addRootView(ownerPluginID: String, _ contribution: @escaping @MainActor (AnyView) -> AnyView?)

    /// 登记引导视图（单槽位，取首个）。
    func addGuideView(ownerPluginID: String, _ view: AnyView)

    /// 登记状态视图。
    func addStateView(ownerPluginID: String, _ view: AnyView)

    /// 登记海报视图。
    func addPosterView(ownerPluginID: String, _ view: AnyView)

    /// 登记标签页视图贡献（reason/demoMode 守卫由插件闭包自行处理）。
    func addTabView(
        ownerPluginID: String,
        _ contribution: @escaping @MainActor (_ reason: String, _ demoMode: Bool) -> (view: AnyView, label: String)?
    )

    /// 登记设置视图。
    func addSettingView(ownerPluginID: String, _ view: AnyView)

    /// 登记设置导航项。
    func addSettingNavigationItem(ownerPluginID: String, _ item: PluginSettingNavigationItem)

    /// 登记由应用核心提供的设置导航项，不受插件启停状态过滤。
    func addSystemSettingNavigationItem(_ item: PluginSettingNavigationItem)

    /// 登记工具栏按钮。
    func addToolBarButtons(ownerPluginID: String, _ buttons: [(id: String, view: AnyView)])

    /// 登记主题贡献。
    func addThemeContributions(ownerPluginID: String, _ contributions: [LumiUIThemeContribution])

    /// 登记播放控制区封面（单槽位，取首个）。
    func addHeroView(ownerPluginID: String, _ view: AnyView)

    /// 登记播放控制区右侧封面（单槽位，取首个）。
    func addRightAlbumView(ownerPluginID: String, _ view: AnyView)

    /// 登记播放控制区按钮组（单槽位，取首个）。
    func addControlButtonsView(ownerPluginID: String, _ view: AnyView)

    /// 登记播放控制区进度条（单槽位，取首个）。
    func addProgressView(ownerPluginID: String, _ view: AnyView)

    /// 撤回某插件（owner id）登记的全部贡献。
    func remove(owner: String)

    /// 失效全部聚合缓存并通知观察者。
    func invalidateCaches()
}
