import ProviderTheme
import CisumUIComponents
import LumiUI
import MagicKit

/// 主题设置页面需要的最小主题能力。
///
/// ViewModel 不直接依赖 `ThemeProviding`；Provider 由插件入口适配后注入。
@MainActor
protocol ThemeSettingsCapability: AnyObject {
    var allThemeContributions: [LumiUIThemeContribution] { get }
    var selectedThemeID: String { get }

    func selectTheme(_ themeID: String)
}

/// 将内核主题 Provider 收窄成主题设置能力。
@MainActor
final class ThemeSettingsCapabilityAdapter: ThemeSettingsCapability, SuperLog {
    nonisolated static let verbose = false

    private weak var theme: (any ThemeProviding)?

    init(theme: any ThemeProviding) {
        self.theme = theme
    }

    var allThemeContributions: [LumiUIThemeContribution] {
        theme?.allThemeContributions ?? []
    }

    var selectedThemeID: String {
        theme?.selectedThemeID ?? ""
    }

    func selectTheme(_ themeID: String) {
        theme?.selectTheme(themeID)
    }
}