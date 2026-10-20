import LumiUI
import SwiftUI

/// 空仓库引导 关于视图 —— Landing 落地页。
struct RepositoryGuidePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "sparkles",
                accent: theme.primary,
                tagline: String(localized: "A first-run guide for an empty repository.", bundle: .module),
                chips: [String(localized: "Repository Guide", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                    .init(icon: "music.note", tint: theme.primary, title: String(localized: "Empty Repository", bundle: .module), description: String(localized: "Appears only when the repository is empty.", bundle: .module)),
                    .init(icon: "ellipsis", tint: theme.info, title: String(localized: "Repository Access", bundle: .module), description: String(localized: "Points at the ⋯ button that opens the repository.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
