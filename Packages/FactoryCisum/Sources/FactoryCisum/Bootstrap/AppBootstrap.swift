import LumiUI
import Foundation

/// 应用启动常量。
public enum AppBootstrap {
    /// 应用名称。
    public static let appName = "Cisum"

    /// 主窗口 ID。
    public static let mainWindowID = "cisum.main"

    /// 默认主窗口尺寸。
    ///
    /// 高于 ``AppResponsivePlayerLayoutMetrics`` 的最小窗口尺寸：最小值保证
    /// 布局不塌陷，默认值则给播放器一个能直接显示内容的高度。
    public static let defaultWindowSize = CGSize(width: 400, height: 600)

    /// 设置窗口 ID。
    public static let settingsWindowID = "cisum.settings"

    /// 默认设置窗口尺寸。
    public static let defaultSettingsWindowSize = CGSize(width: 900, height: 640)

}
