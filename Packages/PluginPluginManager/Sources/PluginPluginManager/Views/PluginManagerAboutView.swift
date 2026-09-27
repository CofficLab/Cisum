import CisumUIComponents
import LumiUI
import SwiftUI

/// 插件管理器关于视图 —— Landing 落地页（对齐 Lumi `PluginManagerAboutView`）。
///
/// Hero 横幅 + 核心能力分区 + 入口位置分区，展示插件管理页能做什么。
struct PluginManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            entriesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "puzzlepiece.extension",
            accent: theme.primary,
            tagline: String(localized: "Manage all registered plugins: view, search, filter by category, and enable or disable.", bundle: .module),
            chips: [String(localized: "Search Plugins", bundle: .module), String(localized: "Category Filter", bundle: .module)],
            metrics: [
                .init(value: String(localized: "All", bundle: .module), label: String(localized: "Configurable Plugins", bundle: .module)),
                .init(value: String(localized: "Always Enabled", bundle: .module), label: String(localized: "Strategy", bundle: .module))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: String(localized: "Core Capabilities", bundle: .module), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "square.grid.2x2", tint: theme.primary,
                      title: String(localized: "Plugin Catalog", bundle: .module),
                      description: String(localized: "Shows all user-configurable plugins, visually distinguished by enable state.", bundle: .module)),
                .init(icon: "magnifyingglass", tint: theme.info,
                      title: String(localized: "Search & Filter", bundle: .module),
                      description: String(localized: "Quickly locate plugins by name, identifier, or description keyword.", bundle: .module)),
                .init(icon: "folder", tint: theme.warning,
                      title: String(localized: "Category Filter", bundle: .module),
                      description: String(localized: "Filter the list by category such as Music Library, Playback, and Theme.", bundle: .module)),
                .init(icon: "info.circle", tint: theme.info,
                      title: String(localized: "Plugin Details", bundle: .module),
                      description: String(localized: "Shows each plugin's About page and enable-state control.", bundle: .module)),
                .init(icon: "arrow.up.arrow.down", tint: theme.primary,
                      title: String(localized: "Enable Management", bundle: .module),
                      description: String(localized: "Enables or disables plugins at runtime and persists user overrides.", bundle: .module))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: String(localized: "Where to Find It", bundle: .module), icon: "cursorarrow.click.2") {
            LandingInventory(
                tint: theme.primary,
                items: [
                    .init(icon: "gearshape", title: String(localized: "Settings → Plugin Manager", bundle: .module), description: String(localized: "Opens in the Plugin Manager navigation item of the main Settings window.", bundle: .module)),
                    .init(icon: "book", title: String(localized: "Manual", bundle: .module), description: String(localized: "You can read this manual in Settings → General → Manuals.", bundle: .module))
                ]
            )
        }
        .landingAppear(delay: 0.1)
    }
}
