import CisumUIComponents
import LumiUI
import SwiftUI

/// 存储管理 关于视图 —— Landing 落地页。
struct StoragePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "externaldrive",
                accent: theme.primary,
                tagline: String(localized: "Manage app data storage location, migration, and file browsing", bundle: .module),
                chips: [String(localized: "Storage Management", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "externaldrive", tint: theme.primary, title: String(localized: "Storage Location", bundle: .module), description: String(localized: "Configures the data storage directory.", bundle: .module)),
                .init(icon: "arrow.triangle.2.circlepath", tint: theme.info, title: String(localized: "Migrate", bundle: .module), description: String(localized: "Moves data between storage locations.", bundle: .module)),
                .init(icon: "folder", tint: theme.success, title: String(localized: "File Browser", bundle: .module), description: String(localized: "Browses the app's data files.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
