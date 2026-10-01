import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书控制 关于视图 —— Landing 落地页。
struct BookControlPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "playpause",
                accent: theme.primary,
                tagline: String(localized: "Control play, pause, and chapter navigation for the current audiobook", bundle: .module),
                chips: [String(localized: "Audiobook Controls", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "playpause", tint: theme.primary, title: String(localized: "Play / Pause", bundle: .module), description: String(localized: "One-click toggle of the playback state.", bundle: .module)),
                .init(icon: "backward.end", tint: theme.info, title: String(localized: "Previous Chapter", bundle: .module), description: String(localized: "Switches to the previous chapter.", bundle: .module)),
                .init(icon: "forward.end", tint: theme.success, title: String(localized: "Next Chapter", bundle: .module), description: String(localized: "Switches to the next chapter.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
