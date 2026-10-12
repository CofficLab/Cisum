import CisumUIComponents
import LumiUI
import SwiftUI

/// 打开当前 关于视图 —— Landing 落地页。
struct OpenButtonPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "folder",
                accent: theme.primary,
                tagline: String(localized: "Provides an Open Current entry in the toolbar to quickly locate the current file", bundle: .module),
                chips: [String(localized: "Open Current", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "folder", tint: theme.primary, title: String(localized: "Open File", bundle: .module), description: String(localized: "Shows the current file in the file manager.", bundle: .module)),
                .init(icon: "arrow.up.forward.square", tint: theme.info, title: String(localized: "Quick Jump", bundle: .module), description: String(localized: "Locates the current media with one click.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
