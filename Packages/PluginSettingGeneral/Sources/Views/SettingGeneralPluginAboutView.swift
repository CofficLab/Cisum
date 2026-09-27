import CisumUIComponents
import LumiUI
import SwiftUI

/// 通用设置 关于视图 —— Landing 落地页。
struct SettingGeneralPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "gearshape",
                accent: theme.primary,
                tagline: String(localized: "Provides general settings such as app info and manuals in the Settings window.", bundle: .module),
                chips: [String(localized: "General Settings", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "app", tint: theme.primary, title: String(localized: "App Info", bundle: .module), description: String(localized: "Shows basic info such as name and version.", bundle: .module)),
                .init(icon: "book", tint: theme.info, title: String(localized: "Manual", bundle: .module), description: String(localized: "Browse the manuals contributed by each plugin.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
