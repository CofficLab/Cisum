import LumiUI
import SwiftUI

/// 视频库 关于视图 —— Landing 落地页。
struct VideoLibraryAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "film.stack",
                accent: theme.primary,
                tagline: String(localized: "Play the videos stored in your own folder", bundle: .module),
                chips: [String(localized: "Video Library", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module)),
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                    .init(icon: "play.rectangle.fill", tint: theme.primary, title: String(localized: "Playback", bundle: .module), description: String(localized: "Plays back MP4, MKV, MOV and more with hardware decoding on Mac.", bundle: .module)),
                    .init(icon: "square.grid.2x2", tint: theme.info, title: String(localized: "Library", bundle: .module), description: String(localized: "Scans the selected folder and groups videos by tags and favorites.", bundle: .module)),
                    .init(icon: "backward.end.fill", tint: theme.success, title: String(localized: "Continue", bundle: .module), description: String(localized: "Remembers the playback position of every video and resumes where you stopped.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
