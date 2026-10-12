import CisumUIComponents
import LumiUI
import SwiftUI

/// 复制 关于视图 —— Landing 落地页。
struct CopyPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "doc.on.doc",
                accent: theme.primary,
                tagline: String(localized: "Copy current music files to the clipboard with one click", bundle: .module),
                chips: [String(localized: "Copy", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "doc.on.doc", tint: theme.primary, title: String(localized: "Copy File", bundle: .module), description: String(localized: "Copies the current music to the clipboard.", bundle: .module)),
                .init(icon: "checkmark.circle", tint: theme.info, title: String(localized: "Completion Toast", bundle: .module), description: String(localized: "Gives status feedback after copying.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
