import CisumUIComponents
import LumiUI
import SwiftUI

/// 文件日志 关于视图 —— Landing 落地页。
struct FileLogPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "doc.text",
                accent: theme.primary,
                tagline: String(localized: "Logs app runtime and file operations to help troubleshoot issues", bundle: .module),
                chips: [String(localized: "File Log", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "doc.text", tint: theme.primary, title: String(localized: "Logging", bundle: .module), description: String(localized: "Records key runtime events.", bundle: .module)),
                .init(icon: "magnifyingglass", tint: theme.info, title: String(localized: "Search Logs", bundle: .module), description: String(localized: "Searches logs by keyword.", bundle: .module)),
                .init(icon: "trash", tint: theme.success, title: String(localized: "Clean Up", bundle: .module), description: String(localized: "Clears historical logs.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
