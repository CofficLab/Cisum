import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeAuroraPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeAuroraPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeAuroraPlugin()
    public let order = 120
    public let iconName = AuroraTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeAuroraPlugin.self),
        name: AuroraTheme().displayName,
        description: AuroraTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeAuroraPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeAuroraPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 120, themeId: AuroraTheme().identifier),
        chromeTheme: AuroraTheme(),
        editorThemeId: AuroraTheme().identifier
    )]
    }
}