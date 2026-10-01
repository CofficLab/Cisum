import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书进度 关于视图 —— Landing 落地页。
struct BookProgressPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "waveform",
                accent: theme.primary,
                tagline: String(localized: "Display and scrub audiobook progress, remembering the last listening position", bundle: .module),
                chips: [String(localized: "Audiobook Progress", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "waveform", tint: theme.primary, title: String(localized: "Progress Bar", bundle: .module), description: String(localized: "Shows the current playback position.", bundle: .module)),
                .init(icon: "gauge.with.dots.needle.67percent", tint: theme.info, title: String(localized: "Seek", bundle: .module), description: String(localized: "Drag to jump to any position.", bundle: .module)),
                .init(icon: "bookmark", tint: theme.success, title: String(localized: "Remember Position", bundle: .module), description: String(localized: "Automatically remembers where you left off.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
