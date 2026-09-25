import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeMidnightPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeMidnightPlugin()
    public static let metadata = PluginMetadata(
        displayName: MidnightTheme().displayName,
        description: MidnightTheme().description,
        iconName: MidnightTheme().iconName,
        order: 160,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeMidnightPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeMidnightPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 160, themeId: MidnightTheme().identifier),
        chromeTheme: MidnightTheme(),
        editorThemeId: MidnightTheme().identifier
    )]
    }
}
