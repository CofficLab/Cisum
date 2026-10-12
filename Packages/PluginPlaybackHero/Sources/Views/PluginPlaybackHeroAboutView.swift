import CisumUIComponents
import LumiUI
import SwiftUI

/// 播放封面 关于视图 —— Landing 落地页。
struct PlaybackHeroPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "photo",
                accent: theme.primary,
                tagline: String(localized: "Cover and title for the player control area.", bundle: .module),
                chips: [String(localized: "Playback Control", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                    .init(icon: "music.note", tint: theme.primary, title: String(localized: "Cover Display", bundle: .module), description: String(localized: "Audio shows the cover; video shows the frame.", bundle: .module)),
                    .init(icon: "textformat", tint: theme.info, title: String(localized: "Title Display", bundle: .module), description: String(localized: "Shows the title of the current track.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
