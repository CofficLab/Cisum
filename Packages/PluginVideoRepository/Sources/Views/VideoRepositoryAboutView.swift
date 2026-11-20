import LumiUI
import SwiftUI

/// 视频仓库 关于视图 —— Landing 落地页。
struct VideoRepositoryAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "externaldrive.badge.timachine",
                accent: theme.primary,
                tagline: String(localized: "Cisum keeps the video repository inside the storage location you chose", bundle: .module),
                chips: [String(localized: "Video Repository", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module)),
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                    .init(icon: "folder", tint: theme.primary, title: String(localized: "Folder", bundle: .module), description: String(localized: "Creates the video repository inside the shared storage root, next to the music and audiobook libraries.", bundle: .module)),
                    .init(icon: "tag", tint: theme.info, title: String(localized: "Organize", bundle: .module), description: String(localized: "Tag, rate and favorite videos, and rename or delete files in place.", bundle: .module)),
                    .init(icon: "clock.arrow.circlepath", tint: theme.success, title: String(localized: "Progress", bundle: .module), description: String(localized: "Remembers where you stopped watching every video.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
