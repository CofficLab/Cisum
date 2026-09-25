import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeGraphiteBlackPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeGraphiteBlackPlugin()
    public static let metadata = PluginMetadata(
        displayName: GraphiteBlackTheme().displayName,
        description: GraphiteBlackTheme().description,
        iconName: GraphiteBlackTheme().iconName,
        order: 155,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeGraphiteBlackPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeGraphiteBlackPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 155, themeId: GraphiteBlackTheme().identifier),
        chromeTheme: GraphiteBlackTheme(),
        editorThemeId: GraphiteBlackTheme().identifier
    )]
    }
}
