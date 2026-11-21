import LumiUI
import SwiftUI

/// 视频播放 关于视图 —— Landing 落地页。
struct VideoPlaybackAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "play.rectangle",
                accent: theme.primary,
                tagline: String(localized: "Play the videos in your library", bundle: .module),
                chips: [String(localized: "Video Playback", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module)),
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                    .init(icon: "cpu", tint: theme.primary, title: String(localized: "Smart Engine", bundle: .module), description: String(localized: "Picks a decoder that can handle the file, and falls back when it cannot.", bundle: .module)),
                    .init(icon: "forward.end", tint: theme.info, title: String(localized: "Transport", bundle: .module), description: String(localized: "Play, pause, seek and change playback speed.", bundle: .module)),
                    .init(icon: "memorychip", tint: theme.success, title: String(localized: "Hardware", bundle: .module), description: String(localized: "Uses hardware decoding where the platform provides it.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
