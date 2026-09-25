import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeForestPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeForestPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeForestPlugin()
    public let order = 150
    public let iconName = ForestTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeForestPlugin.self),
        name: ForestTheme().displayName,
        description: ForestTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeForestPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeForestPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 150, themeId: ForestTheme().identifier),
        chromeTheme: ForestTheme(),
        editorThemeId: ForestTheme().identifier
    )]
    }
}