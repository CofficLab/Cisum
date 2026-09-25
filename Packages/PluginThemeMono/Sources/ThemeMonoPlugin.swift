import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeMonoPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeMonoPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeMonoPlugin()
    public let order = 170
    public let iconName = MonoTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeMonoPlugin.self),
        name: MonoTheme().displayName,
        description: MonoTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeMonoPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeMonoPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 170, themeId: MonoTheme().identifier),
        chromeTheme: MonoTheme(),
        editorThemeId: MonoTheme().identifier
    )]
    }
}