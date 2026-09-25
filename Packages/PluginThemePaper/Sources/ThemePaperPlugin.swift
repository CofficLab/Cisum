import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemePaperPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemePaperPlugin()
    public static let metadata = PluginMetadata(
        displayName: PaperTheme().displayName,
        description: PaperTheme().description,
        iconName: PaperTheme().iconName,
        order: 200,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemePaperPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemePaperPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 200, themeId: PaperTheme().identifier),
        chromeTheme: PaperTheme(),
        editorThemeId: PaperTheme().identifier
    )]
    }
}
