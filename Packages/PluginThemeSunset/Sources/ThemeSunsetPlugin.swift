import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeSunsetPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeSunsetPlugin()
    public static let metadata = PluginMetadata(
        displayName: SunsetTheme().displayName,
        description: SunsetTheme().description,
        iconName: SunsetTheme().iconName,
        order: 140,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeSunsetPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeSunsetPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 140, themeId: SunsetTheme().identifier),
        chromeTheme: SunsetTheme(),
        editorThemeId: SunsetTheme().identifier
    )]
    }
}
