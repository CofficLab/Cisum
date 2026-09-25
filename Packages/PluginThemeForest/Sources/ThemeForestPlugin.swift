import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeForestPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeForestPlugin()
    public static let metadata = PluginMetadata(
        displayName: ForestTheme().displayName,
        description: ForestTheme().description,
        iconName: ForestTheme().iconName,
        order: 150,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeForestPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeForestPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 150, themeId: ForestTheme().identifier),
        chromeTheme: ForestTheme(),
        editorThemeId: ForestTheme().identifier
    )]
    }
}
