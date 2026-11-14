import Foundation

/// Cisum 加载的主题子集。
///
/// LumiThemePack 的共享目录包含 19 个主题，那是 Lumi 这类综合型工具的全量
/// 外观库；Cisum 定位在播放器 / 有声书，只需要少数几套代表性配色，
/// 因此只注册下列白名单内的目录主题。
///
/// 白名单之外的目录主题不会进入 `ThemeProviding.themes`，
/// 「外观」设置页与主题菜单随之只展示该子集。
public enum CisumThemeSelection {
    /// 目录主题 id 白名单。
    ///
    /// - `lumi`：森林墨，默认主题，与 App 图标同色系。
    /// - `midnight`：午夜幽蓝，暗色场景。
    /// - `river`：河流青，清爽亮色。
    /// - `autumn`：秋枫橙，暖色。
    ///
    /// 另有 ProviderTheme 的三个基础外观（跟随系统 / 固定暗色 / 固定亮色）
    /// 由 `DefaultThemeProviding` 内置注册，无需在此列出。
    public static let catalogueIDs: [String] = [
        "lumi",
        "midnight",
        "river",
        "autumn",
    ]
}
