import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemePaperPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemePaperPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemePaperPlugin()
    public let order = 200
    public let iconName = PaperTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemePaperPlugin.self),
        name: PaperTheme().displayName,
        description: PaperTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemePaperPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemePaperPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 200, themeId: PaperTheme().identifier),
        chromeTheme: PaperTheme(),
        editorThemeId: PaperTheme().identifier
    )]
    }
}