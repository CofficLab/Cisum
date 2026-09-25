import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeCisumPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeCisumPlugin()
    public static let metadata = PluginMetadata(
        displayName: CisumTheme().displayName,
        description: CisumTheme().description,
        iconName: CisumTheme().iconName,
        order: 100,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeCisumPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeCisumPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 100, themeId: CisumTheme().identifier),
        chromeTheme: CisumTheme(),
        editorThemeId: CisumTheme().identifier
    )]
    }
}
