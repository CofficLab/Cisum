import CisumUIComponents
import LumiUI
import SwiftUI

/// 欢迎页 关于视图 —— Landing 落地页。
struct WelcomePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "hand.wave",
                accent: theme.primary,
                tagline: String(localized: "Shows a welcome guide on first launch to help you get started", bundle: .module),
                chips: [String(localized: "Welcome Page", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "hand.wave", tint: theme.primary, title: String(localized: "Welcome Guide", bundle: .module), description: String(localized: "Shows welcome content on first launch.", bundle: .module)),
                .init(icon: "checkmark.circle", tint: theme.info, title: String(localized: "Quick Start", bundle: .module), description: String(localized: "Guides storage setup and basic operations.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
