import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeStudioBluePlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeStudioBluePlugin()
    public static let metadata = PluginMetadata(
        displayName: StudioBlueTheme().displayName,
        description: StudioBlueTheme().description,
        iconName: StudioBlueTheme().iconName,
        order: 130,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeStudioBluePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeStudioBluePluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 130, themeId: StudioBlueTheme().identifier),
        chromeTheme: StudioBlueTheme(),
        editorThemeId: StudioBlueTheme().identifier
    )]
    }
}
