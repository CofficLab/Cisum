import CisumUIComponents
import LumiUI
import SwiftUI

/// 播放控制按钮 关于视图 —— Landing 落地页。
struct PluginControlButtonsAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "playpause.fill",
                accent: theme.primary,
                tagline: String(localized: "The control button group at the bottom of the player.", bundle: .module),
                chips: [String(localized: "Playback Control", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                    .init(icon: "backward.end.fill", tint: theme.primary, title: String(localized: "Track Switching", bundle: .module), description: String(localized: "Quickly switches between previous and next tracks.", bundle: .module)),
                    .init(icon: "playpause.fill", tint: theme.info, title: String(localized: "Playback Control", bundle: .module), description: String(localized: "Plays and pauses the current track.", bundle: .module)),
                    .init(icon: "repeat", tint: theme.success, title: String(localized: "Play Mode", bundle: .module), description: String(localized: "Cycles through sequential, repeat, and other modes.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
