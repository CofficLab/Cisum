import CisumUIComponents
import LumiUI
import SwiftUI

/// 播放进度 关于视图 —— Landing 落地页。
struct PlaybackProgressPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "waveform",
                accent: theme.primary,
                tagline: String(localized: "A progress bar for the player control area.", bundle: .module),
                chips: [String(localized: "Playback Control", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                    .init(icon: "gauge.with.dots.needle.50percent", tint: theme.primary, title: String(localized: "Progress Display", bundle: .module), description: String(localized: "Shows the current playback position in real time.", bundle: .module)),
                    .init(icon: "hand.draw", tint: theme.info, title: String(localized: "Drag Control", bundle: .module), description: String(localized: "Drag the progress bar to adjust the position.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
