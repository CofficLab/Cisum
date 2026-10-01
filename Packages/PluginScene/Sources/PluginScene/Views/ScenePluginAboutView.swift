import CisumUIComponents
import LumiUI
import SwiftUI

/// 场景管理 关于视图 —— Landing 落地页。
struct ScenePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "rectangle.3.group",
                accent: theme.primary,
                tagline: String(localized: "Manages app scene switching and state (Music Library / Audiobooks)", bundle: .module),
                chips: [String(localized: "Scene Management", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "rectangle.3.group", tint: theme.primary, title: String(localized: "Scene Switching", bundle: .module), description: String(localized: "Switches between the music library and audiobooks.", bundle: .module)),
                .init(icon: "arrow.left.arrow.right", tint: theme.info, title: String(localized: "State Management", bundle: .module), description: String(localized: "Maintains the current scene state.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
