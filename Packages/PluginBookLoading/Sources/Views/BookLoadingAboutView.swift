import LumiUI
import SwiftUI

/// 有声书载入 关于视图 —— Landing 落地页。
struct BookLoadingAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "icloud.and.arrow.down",
                accent: theme.primary,
                tagline: String(localized: "Show which audiobook chapter is loading from iCloud and let people cancel or retry.", bundle: .module),
                chips: [String(localized: "Audiobook Loading", bundle: .module)],
                metrics: [
                    .init(value: "1.0.0", label: String(localized: "Version", bundle: .module)),
                    .init(value: String(localized: "Plugin", bundle: .module), label: String(localized: "Type", bundle: .module))
                ]
            )
            .landingAppear()

            LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "sparkles") {
                LandingFeatureGrid(items: [
                    .init(icon: "text.book.closed", tint: theme.primary, title: String(localized: "Named Loading", bundle: .module), description: String(localized: "Names the chapter that is being fetched from iCloud.", bundle: .module)),
                    .init(icon: "xmark.circle", tint: theme.info, title: String(localized: "Cancel", bundle: .module), description: String(localized: "Ends the wait quietly without presenting a failure.", bundle: .module)),
                    .init(icon: "arrow.clockwise", tint: theme.success, title: String(localized: "Retry", bundle: .module), description: String(localized: "Re-runs the last failed load with the same start time.", bundle: .module)),
                ], minColumnWidth: 180)
            }
            .landingAppear(delay: 0.05)
        }
    }
}
