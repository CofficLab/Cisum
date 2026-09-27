import CisumUIComponents
import LumiUI
import SwiftUI

/// 日光银 关于视图 —— Landing 落地页。
struct ThemeDaylightSilverPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "sun.max",
                accent: theme.primary,
                tagline: String(localized: "A bright, soft silver-toned theme", bundle: .module),
                chips: [String(localized: "Daylight Silver", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "paintpalette", tint: theme.primary, title: String(localized: "Theme Appearance", bundle: .module), description: String(localized: "The overall palette and texture of the Daylight Silver theme.", bundle: .module)),
                .init(icon: "circle.lefthalf.filled", tint: theme.info, title: String(localized: "Light/Dark Adaptation", bundle: .module), description: String(localized: "Adapts to the system light/dark mode.", bundle: .module)),
                .init(icon: "arrow.2.squarepath", tint: theme.success, title: String(localized: "Instant Switching", bundle: .module), description: String(localized: "Applies immediately, no relaunch needed.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
