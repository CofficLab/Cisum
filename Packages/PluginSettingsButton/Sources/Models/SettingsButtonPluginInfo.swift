import Foundation
import LumiUI

public enum SettingsButtonPluginInfo {
    public static let description = String(localized: "Settings Button", bundle: .module)
    public static let iconName = "gearshape"
    public static let toolbarItemId = "settings-button"

    /// iOS 导航栏项 id（设置齿轮）。
    ///
    /// 与 macOS 工具栏项分开命名：两端的贡献注册表不同（`ToolbarProviding` vs
    /// `IOSNavigationBarProviding`），共用一个 id 会在撤回时误伤另一端。
    public static let navigationBarItemId = "settings-button.navigation-bar"

    /// 设置窗口 ID，与 `FactoryCisum.AppBootstrap.settingsWindowID` 保持一致。
    ///
    /// 插件包不能反向依赖 FactoryCisum（避免循环依赖），故在此保留同一常量。
    public static let settingsWindowID = "cisum.settings"
}
