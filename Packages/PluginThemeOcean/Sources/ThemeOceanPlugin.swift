import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeOceanPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeOceanPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeOceanPlugin()
    public let order = 190
    public let iconName = OceanTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeOceanPlugin.self),
        name: OceanTheme().displayName,
        description: OceanTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeOceanPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeOceanPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 190, themeId: OceanTheme().identifier),
        chromeTheme: OceanTheme(),
        editorThemeId: OceanTheme().identifier
    )]
    }
}