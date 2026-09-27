import CisumUIComponents
import LumiUI
import SwiftUI

/// 外观设置 关于视图 —— Landing 落地页。
struct ThemeSettingsPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "paintpalette",
                accent: theme.primary,
                tagline: String(localized: "Provides theme selection and appearance settings in the settings window", bundle: .module),
                chips: [String(localized: "Appearance Settings", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "paintpalette", tint: theme.primary, title: String(localized: "Theme Selection", bundle: .module), description: String(localized: "Chooses an appearance from all themes.", bundle: .module)),
                .init(icon: "moon", tint: theme.info, title: String(localized: "Dark Mode", bundle: .module), description: String(localized: "Toggles between light and dark appearance.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
