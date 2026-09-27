import CisumUIComponents
import LumiUI
import SwiftUI

/// 小组件控制 关于视图 —— Landing 落地页。
struct AudioWidgetControlPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "rectangle.grid.2x2",
                accent: theme.primary,
                tagline: String(localized: "Control music playback via desktop widgets", bundle: .module),
                chips: [String(localized: "Widget Control", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "rectangle.grid.2x2", tint: theme.primary, title: String(localized: "Widget", bundle: .module), description: String(localized: "Shows playback state in the desktop widget.", bundle: .module)),
                .init(icon: "playpause.fill", tint: theme.info, title: String(localized: "Quick Controls", bundle: .module), description: String(localized: "Plays / pauses directly from the widget.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
