import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeNebulaPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeNebulaPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeNebulaPlugin()
    public let order = 180
    public let iconName = NebulaTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeNebulaPlugin.self),
        name: NebulaTheme().displayName,
        description: NebulaTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeNebulaPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeNebulaPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 180, themeId: NebulaTheme().identifier),
        chromeTheme: NebulaTheme(),
        editorThemeId: NebulaTheme().identifier
    )]
    }
}