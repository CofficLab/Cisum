import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeMonoPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeMonoPlugin()
    public static let metadata = PluginMetadata(
        displayName: MonoTheme().displayName,
        description: MonoTheme().description,
        iconName: MonoTheme().iconName,
        order: 170,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeMonoPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeMonoPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 170, themeId: MonoTheme().identifier),
        chromeTheme: MonoTheme(),
        editorThemeId: MonoTheme().identifier
    )]
    }
}
