import CisumUIComponents
import LumiUI
import SwiftUI

/// 音乐演示 关于视图 —— Landing 落地页。
struct AudioDemoPluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "wand.and.stars",
                accent: theme.primary,
                tagline: String(localized: "Provides demo data and experience for music playback", bundle: .module),
                chips: [String(localized: "Music Demo", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "wand.and.stars", tint: theme.primary, title: String(localized: "Demo Data", bundle: .module), description: String(localized: "Generates demo music content with one click.", bundle: .module)),
                .init(icon: "play.rectangle", tint: theme.info, title: String(localized: "Quick Experience", bundle: .module), description: String(localized: "Experience playback without real files.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
