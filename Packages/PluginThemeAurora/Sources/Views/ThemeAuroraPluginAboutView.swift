import CisumUIComponents
import LumiUI
import SwiftUI

/// 极光 关于视图 —— Landing 落地页。
struct ThemeAuroraPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "aurora",
                accent: theme.primary,
                tagline: String(localized: "A deep blue-purple gradient, like an aurora in the night sky", bundle: .module),
                chips: [String(localized: "Aurora", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "paintpalette", tint: theme.primary, title: String(localized: "Theme Appearance", bundle: .module), description: String(localized: "The overall palette and texture of the Aurora theme.", bundle: .module)),
                .init(icon: "circle.lefthalf.filled", tint: theme.info, title: String(localized: "Light/Dark Adaptation", bundle: .module), description: String(localized: "Adapts to the system light/dark mode.", bundle: .module)),
                .init(icon: "arrow.2.squarepath", tint: theme.success, title: String(localized: "Instant Switching", bundle: .module), description: String(localized: "Applies immediately, no relaunch needed.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
