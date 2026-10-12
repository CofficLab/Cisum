import CisumUIComponents
import LumiUI
import SwiftUI

/// 播放引擎 关于视图 —— Landing 落地页。
struct PluginPlayBackAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "play.circle",
                accent: theme.primary,
                tagline: String(localized: "A unified playback engine with playback-state management.", bundle: .module),
                chips: [String(localized: "Playback Engine", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "play.circle", tint: theme.primary, title: String(localized: "Playback Engine", bundle: .module), description: String(localized: "Drives audio decoding and playback control.", bundle: .module)),
                .init(icon: "arrow.clockwise", tint: theme.info, title: String(localized: "Relaunch Resume", bundle: .module), description: String(localized: "Restores the last played file after relaunch.", bundle: .module)),
                .init(icon: "internaldrive", tint: theme.success, title: String(localized: "State Persistence", bundle: .module), description: String(localized: "Records the current playing file to disk.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
