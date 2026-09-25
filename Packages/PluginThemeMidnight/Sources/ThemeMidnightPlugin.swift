import ProviderDocsView
import CisumUIComponents
import CisumKernelSupport
import SwiftUI
import MagicKit

@MainActor
public final class ThemeMidnightPlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ThemeMidnightPlugin.self)

    nonisolated static let verbose = false

    public static let shared = ThemeMidnightPlugin()
    public let order = 160
    public let iconName = MidnightTheme().iconName
    public let metadata = PluginMetadata(
        id: String(describing: ThemeMidnightPlugin.self),
        name: MidnightTheme().displayName,
        description: MidnightTheme().description,
        version: "1.0.0",
        category: .design,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ThemeMidnightPluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ThemeMidnightPluginManualView() })
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
        sortKey: ThemeSortKey(pluginOrder: 160, themeId: MidnightTheme().identifier),
        chromeTheme: MidnightTheme(),
        editorThemeId: MidnightTheme().identifier
    )]
    }
}