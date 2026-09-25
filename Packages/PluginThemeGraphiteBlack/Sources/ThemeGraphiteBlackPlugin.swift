import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeGraphiteBlackPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeGraphiteBlackPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeGraphiteBlackPlugin()
    public let order = 155
    public let iconName = GraphiteBlackTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeGraphiteBlackPlugin.self),
        name: GraphiteBlackTheme().displayName,
        description: GraphiteBlackTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeGraphiteBlackPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeGraphiteBlackPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 155, themeId: GraphiteBlackTheme().identifier),
        chromeTheme: GraphiteBlackTheme(),
        editorThemeId: GraphiteBlackTheme().identifier
    )]
    }
}