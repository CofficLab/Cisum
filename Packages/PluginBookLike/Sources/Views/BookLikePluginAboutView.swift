import CisumUIComponents
import LumiUI
import SwiftUI

/// 有声书喜欢 关于视图 —— Landing 落地页。
struct BookLikePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "heart",
                accent: theme.primary,
                tagline: String(localized: "Favorite and mark audiobooks you like", bundle: .module),
                chips: [String(localized: "Audiobook Likes", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "heart", tint: theme.primary, title: String(localized: "Mark as Liked", bundle: .module), description: String(localized: "Favorites the current audiobook with one click.", bundle: .module)),
                .init(icon: "heart.fill", tint: theme.info, title: String(localized: "Liked List", bundle: .module), description: String(localized: "Centrally browses all liked audiobooks.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
