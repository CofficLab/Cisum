import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书播放模式 关于视图 —— Landing 落地页。
struct BookPlayModePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "repeat",
                accent: theme.primary,
                tagline: String(localized: "Switch playback modes: single chapter loop, list loop, shuffle, and more", bundle: .module),
                chips: [String(localized: "Audiobook Play Mode", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "repeat", tint: theme.primary, title: String(localized: "Repeat", bundle: .module), description: String(localized: "Single-chapter / list repeat.", bundle: .module)),
                .init(icon: "shuffle", tint: theme.info, title: String(localized: "Shuffle", bundle: .module), description: String(localized: "Shuffles all chapters.", bundle: .module)),
                .init(icon: "arrow.triangle.2.circlepath", tint: theme.success, title: String(localized: "Sequential", bundle: .module), description: String(localized: "Plays in list order.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
