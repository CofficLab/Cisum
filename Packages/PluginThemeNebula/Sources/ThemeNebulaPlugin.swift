import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeNebulaPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeNebulaPlugin()
    public static let metadata = PluginMetadata(
        displayName: NebulaTheme().displayName,
        description: NebulaTheme().description,
        iconName: NebulaTheme().iconName,
        order: 180,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeNebulaPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeNebulaPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 180, themeId: NebulaTheme().identifier),
        chromeTheme: NebulaTheme(),
        editorThemeId: NebulaTheme().identifier
    )]
    }
}
