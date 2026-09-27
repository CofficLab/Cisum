import Foundation
import CisumUIComponents
import LumiUI

public enum SettingsButtonPluginInfo {
    public static let description = String(localized: "Settings Button", bundle: .module)
    public static let iconName = "gearshape"
    public static let toolbarItemId = "settings-button"

    /// 设置窗口 ID，与 `FactoryCisum.AppBootstrap.settingsWindowID` 保持一致。
    ///
    /// 插件包不能反向依赖 FactoryCisum（避免循环依赖），故在此保留同一常量。
    public static let settingsWindowID = "cisum.settings"
}
