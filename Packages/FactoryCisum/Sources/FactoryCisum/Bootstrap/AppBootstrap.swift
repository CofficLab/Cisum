import CisumUIComponents
import LumiUI
import Foundation

/// 应用启动常量。
public enum AppBootstrap {
    /// 应用名称。
    public static let appName = "Cisum"

    /// 主窗口 ID。
    public static let mainWindowID = "cisum.main"

    /// 默认主窗口尺寸。
    public static let defaultWindowSize = CisumPlayerLayout.defaultWindowSize

    /// 设置窗口 ID。
    public static let settingsWindowID = "cisum.settings"

    /// 默认设置窗口尺寸。
    public static let defaultSettingsWindowSize = CGSize(width: 900, height: 640)

}
