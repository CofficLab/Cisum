import CisumUIComponents
import LumiUI
import SwiftUI

/// 音乐设置 关于视图 —— Landing 落地页。
struct AudioSettingsPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "gearshape",
                accent: theme.primary,
                tagline: String(localized: "Provides music-related settings", bundle: .module),
                chips: [String(localized: "Music Settings", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "gearshape", tint: theme.primary, title: String(localized: "Playback Settings", bundle: .module), description: String(localized: "Configures playback preferences.", bundle: .module)),
                .init(icon: "slider.horizontal.3", tint: theme.info, title: String(localized: "Preferences", bundle: .module), description: String(localized: "Centrally manages music settings.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
