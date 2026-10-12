import CisumUIComponents
import LumiUI
import SwiftUI

/// 音乐库 关于视图 —— Landing 落地页。
struct AudioPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "music.note.list",
                accent: theme.primary,
                tagline: String(localized: "Manage, browse, and play local music files", bundle: .module),
                chips: [String(localized: "Music Library", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "music.note.list", tint: theme.primary, title: String(localized: "Media Library", bundle: .module), description: String(localized: "Manages local music files and browses by category.", bundle: .module)),
                .init(icon: "magnifyingglass", tint: theme.info, title: String(localized: "Search", bundle: .module), description: String(localized: "Quickly locate music by name.", bundle: .module)),
                .init(icon: "play.circle", tint: theme.success, title: String(localized: "Play", bundle: .module), description: String(localized: "Starts playback from the music library.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
