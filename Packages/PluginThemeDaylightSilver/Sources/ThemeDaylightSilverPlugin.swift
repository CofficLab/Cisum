import CisumUIComponents
import CisumKernel
import ProviderDocsView
import SwiftUI
import MagicKit

public actor ThemeDaylightSilverPlugin: SuperPlugin, SuperLog {
    nonisolated static let verbose = false

    public static let shared = ThemeDaylightSilverPlugin()
    public static let metadata = PluginMetadata(
        displayName: DaylightSilverTheme().displayName,
        description: DaylightSilverTheme().description,
        iconName: DaylightSilverTheme().iconName,
        order: 110,
        policy: .alwaysOn,
        category: .theme,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeDaylightSilverPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { ThemeDaylightSilverPluginManualView() })
        }
    }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [LumiUIThemeContribution(
        sortKey: ThemeSortKey(pluginOrder: 110, themeId: DaylightSilverTheme().identifier),
        chromeTheme: DaylightSilverTheme(),
        editorThemeId: DaylightSilverTheme().identifier
    )]
    }
}
