import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeCisumPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeCisumPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeCisumPlugin()
    public let order = 100
    public let iconName = CisumTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeCisumPlugin.self),
        name: CisumTheme().displayName,
        description: CisumTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeCisumPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeCisumPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 100, themeId: CisumTheme().identifier),
        chromeTheme: CisumTheme(),
        editorThemeId: CisumTheme().identifier
    )]
    }
}