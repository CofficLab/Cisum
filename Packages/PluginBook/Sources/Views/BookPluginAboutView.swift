import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书库 关于视图 —— Landing 落地页。
struct BookPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "book",
                accent: theme.primary,
                tagline: String(localized: "Manage, browse, and play local audiobooks", bundle: .module),
                chips: [String(localized: "Audiobook Library", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "book", tint: theme.primary, title: String(localized: "Audiobook Library", bundle: .module), description: String(localized: "Manages local audiobook files.", bundle: .module)),
                .init(icon: "magnifyingglass", tint: theme.info, title: String(localized: "Search", bundle: .module), description: String(localized: "Quickly locate audiobooks by name.", bundle: .module)),
                .init(icon: "play.circle", tint: theme.success, title: String(localized: "Play", bundle: .module), description: String(localized: "Starts playback from the audiobook library.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
