import CisumUIComponents
import LumiUI
import SwiftUI

/// 下载管理 关于视图 —— Landing 落地页。
struct AudioDownloadPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "arrow.down.circle",
                accent: theme.primary,
                tagline: String(localized: "Download and manage music files with offline playback support", bundle: .module),
                chips: [String(localized: "Download Manager", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "arrow.down.circle", tint: theme.primary, title: String(localized: "Download", bundle: .module), description: String(localized: "Downloads music locally.", bundle: .module)),
                .init(icon: "externaldrive.badge.checkmark", tint: theme.info, title: String(localized: "Offline", bundle: .module), description: String(localized: "Plays offline after downloading.", bundle: .module)),
                .init(icon: "list.bullet", tint: theme.success, title: String(localized: "Queue", bundle: .module), description: String(localized: "Views and manages download tasks.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
