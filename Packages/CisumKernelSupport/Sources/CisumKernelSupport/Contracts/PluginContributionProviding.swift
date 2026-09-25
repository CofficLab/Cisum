import CisumUIComponents
import SwiftUI

/// 插件 UI 贡献注册协议（对齐 Lumi 范式）。
///
/// 插件的 UI 贡献不再挂在插件协议上，而是在 `onBoot` / `onEnable` 阶段通过
/// 本协议登记到贡献注册表（实现：`PluginContributionService`），并在
/// `onShutdown` / `onDisable` 时按 `owner`（插件 id）撤回。宿主 UI 通过
/// `PluginProviding` 查询聚合结果。
///
/// 注册时的 `owner` 取内核 `activePluginID`（生命周期回调期间由内核设置），
/// 与 LumiKernel 的 Provider 归属机制一致。
@MainActor
public protocol PluginContributionProviding: AnyObject {
    /// 登记根视图包裹函数（返回 `AnyView?`，nil 表示不包裹）。
    func addRootView(_ contribution: @escaping @MainActor (AnyView) -> AnyView?)

    /// 登记引导视图（单槽位，取首个）。
    func addGuideView(_ view: AnyView)

    /// 登记状态视图。
    func addStateView(_ view: AnyView)

    /// 登记海报视图。
    func addPosterView(_ view: AnyView)

    /// 登记标签页视图贡献（reason/demoMode 守卫由插件闭包自行处理）。
    func addTabView(
        _ contribution: @escaping @MainActor (_ reason: String, _ demoMode: Bool) -> (view: AnyView, label: String)?
    )

    /// 登记设置视图。
    func addSettingView(_ view: AnyView)

    /// 登记设置导航项。
    func addSettingNavigationItem(_ item: PluginSettingNavigationItem)

    /// 登记工具栏按钮。
    func addToolBarButtons(_ buttons: [(id: String, view: AnyView)])

    /// 登记主题贡献。
    func addThemeContributions(_ contributions: [LumiUIThemeContribution])

    /// 登记播放控制区封面（单槽位，取首个）。
    func addHeroView(_ view: AnyView)

    /// 登记播放控制区右侧封面（单槽位，取首个）。
    func addRightAlbumView(_ view: AnyView)

    /// 登记播放控制区按钮组（单槽位，取首个）。
    func addControlButtonsView(_ view: AnyView)

    /// 登记播放控制区进度条（单槽位，取首个）。
    func addProgressView(_ view: AnyView)

    /// 撤回某插件（owner id）登记的全部贡献。
    func remove(owner: String)

    /// 失效全部聚合缓存并通知观察者。
    func invalidateCaches()
}
