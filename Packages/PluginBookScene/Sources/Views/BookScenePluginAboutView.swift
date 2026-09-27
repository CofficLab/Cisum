import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书场景 关于视图 —— Landing 落地页。
struct BookScenePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "book.closed",
                accent: theme.primary,
                tagline: String(localized: "Provides the Audiobooks scene, the main entry for audiobook features", bundle: .module),
                chips: [String(localized: "Audiobook Scene", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "book.closed", tint: theme.primary, title: String(localized: "Audiobook Library", bundle: .module), description: String(localized: "The main interface of the audiobook scene.", bundle: .module)),
                .init(icon: "rectangle.3.group", tint: theme.info, title: String(localized: "Scene Switching", bundle: .module), description: String(localized: "Switches exclusively with other scenes (music library).", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
