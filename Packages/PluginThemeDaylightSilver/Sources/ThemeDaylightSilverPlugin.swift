import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeDaylightSilverPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeDaylightSilverPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeDaylightSilverPlugin()
    public let order = 110
    public let iconName = DaylightSilverTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeDaylightSilverPlugin.self),
        name: DaylightSilverTheme().displayName,
        description: DaylightSilverTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeDaylightSilverPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeDaylightSilverPluginManualView() })
        }
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            contrib.addThemeContributions(self.addThemeContributions())
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