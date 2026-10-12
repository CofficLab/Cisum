import CisumUIComponents
import LumiUI
import SwiftUI

/// 设置按钮 关于视图 —— Landing 落地页。
struct SettingsButtonPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: SettingsButtonPluginInfo.iconName,
                accent: theme.primary,
                tagline: String(localized: "Opens the Settings window from the toolbar.", bundle: .module),
                chips: [String(localized: "Settings", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: SettingsButtonPluginInfo.iconName, tint: theme.primary, title: String(localized: "Single entry to Settings", bundle: .module), description: String(localized: "Opens the Settings window from the toolbar.", bundle: .module)),
                .init(icon: "cursorarrow.click", tint: theme.info, title: String(localized: "Toolbar shortcut", bundle: .module), description: String(localized: "Click the gear button in the upper-right corner of the window.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
