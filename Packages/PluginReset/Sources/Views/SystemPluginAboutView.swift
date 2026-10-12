import CisumUIComponents
import LumiUI
import SwiftUI

/// 重置 关于视图 —— Landing 落地页。
struct SystemPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "arrow.counterclockwise",
                accent: theme.primary,
                tagline: String(localized: "Reset app state or data to restore the initial state", bundle: .module),
                chips: [String(localized: "Reset", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "arrow.counterclockwise", tint: theme.primary, title: String(localized: "Reset", bundle: .module), description: String(localized: "Restores the app to its initial state.", bundle: .module)),
                .init(icon: "exclamationmark.triangle", tint: theme.info, title: String(localized: "Risk Warning", bundle: .module), description: String(localized: "Warns before resetting.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
