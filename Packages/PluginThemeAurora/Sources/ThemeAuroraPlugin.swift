import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeAuroraPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeAuroraPlugin()
    public static let metadata = PluginMetadata(
        displayName: AuroraTheme().displayName,
        description: AuroraTheme().description,
        iconName: AuroraTheme().iconName,
        order: 120,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeAuroraPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeAuroraPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 120, themeId: AuroraTheme().identifier),
        chromeTheme: AuroraTheme(),
        editorThemeId: AuroraTheme().identifier
    )]
    }
}
