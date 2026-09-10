import CisumUIComponents
import SwiftUI

/// 有声书数据库 关于视图 —— Landing 落地页。
struct BookDBViewPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "externaldrive",
                accent: theme.primary,
                tagline: String(localized: "Browse and organize audiobook files in a database view", bundle: .module),
                chips: [String(localized: "Audiobook Database", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "externaldrive", tint: theme.primary, title: String(localized: "Database", bundle: .module), description: String(localized: "Centrally manages the database records of audiobook files.", bundle: .module)),
                .init(icon: "arrow.up.arrow.down", tint: theme.info, title: String(localized: "Sorting", bundle: .module), description: String(localized: "Browses sorted by multiple dimensions.", bundle: .module)),
                .init(icon: "trash", tint: theme.success, title: String(localized: "Clean Up", bundle: .module), description: String(localized: "Removes invalid or duplicate records.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
