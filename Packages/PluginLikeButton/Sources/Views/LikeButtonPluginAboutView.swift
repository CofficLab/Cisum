import CisumUIComponents
import LumiUI
import SwiftUI

/// 喜欢按钮 关于视图 —— Landing 落地页。
struct LikeButtonPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "heart",
                accent: theme.primary,
                tagline: String(localized: "Provides a unified Favorite button in the toolbar", bundle: .module),
                chips: [String(localized: "Like Button", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "heart", tint: theme.primary, title: String(localized: "Toolbar Button", bundle: .module), description: String(localized: "Quickly likes from the toolbar.", bundle: .module)),
                .init(icon: "heart.fill", tint: theme.info, title: String(localized: "State Sync", bundle: .module), description: String(localized: "Stays in sync with each media's like state.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
