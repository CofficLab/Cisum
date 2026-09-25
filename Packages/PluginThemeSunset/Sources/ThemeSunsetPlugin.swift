import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeSunsetPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeSunsetPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeSunsetPlugin()
    public let order = 140
    public let iconName = SunsetTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeSunsetPlugin.self),
        name: SunsetTheme().displayName,
        description: SunsetTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeSunsetPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeSunsetPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 140, themeId: SunsetTheme().identifier),
        chromeTheme: SunsetTheme(),
        editorThemeId: SunsetTheme().identifier
    )]
    }
}