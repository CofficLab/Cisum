import CisumUIComponents
import LumiUI
import SwiftUI

/// 音乐场景 关于视图 —— Landing 落地页。
struct AudioScenePluginAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "music.note.list",
                accent: theme.primary,
                tagline: String(localized: "Provides the Music Library scene, the main entry for music features", bundle: .module),
                chips: [String(localized: "Music Scene", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                .init(icon: "music.note.list", tint: theme.primary, title: String(localized: "Music Library", bundle: .module), description: String(localized: "The main interface of the music scene.", bundle: .module)),
                .init(icon: "rectangle.3.group", tint: theme.info, title: String(localized: "Scene Switching", bundle: .module), description: String(localized: "Switches exclusively with other scenes (audiobooks).", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
