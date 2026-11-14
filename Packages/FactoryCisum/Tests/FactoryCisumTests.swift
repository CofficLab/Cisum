import ProviderControlView
import ProviderContentView
import ProviderRootView
import ProviderCloudDownload
import FactoryCisum
import KernelCore
import ProviderSettingView
import ProviderPlugin
import ProviderTheme
import PluginRootView
import Foundation
import Testing

@MainActor
struct FactoryCisumTests {
    @Test
    func defaultPluginFactoryProducesUniquePluginIDs() {
        let plugins = DefaultPluginFactory().makePlugins()
        let ids = plugins.map(\.id)

        #expect(ids.count > 30)
        #expect(Set(ids).count == ids.count)
    }

    @Test
    func selectedPluginFactoryPreservesBaseOrderAndFiltersByID() {
        let base = DefaultPluginFactory()
        let allIDs = base.makePlugins().map(\.id)
        let allowedIDs = Set(allIDs.prefix(3))
        let selected = SelectedPluginFactory(allowedPluginIDs: allowedIDs, base: base)

        #expect(selected.makePlugins().map(\.id) == allIDs.filter(allowedIDs.contains))
    }

    @Test
    func mainViewAssemblyFallsBackWhenRootProviderIsMissing() {
        let view = CisumBuilder.assembleMainView(kernel: KernelCoreContainer())
        _ = view
    }

    @Test
    func mainViewAssemblyInjectsControlAndContentProviders() throws {
        let kernel = KernelCoreContainer()
        let root = RootViewProvider(kernel: kernel)
        let control = DefaultControlViewProvider()
        let content = DefaultContentViewProvider()
        try kernel.registerProvider((any RootViewProviding).self, root)
        try kernel.registerProvider((any ControlViewProviding).self, control)
        try kernel.registerProvider((any ContentViewProviding).self, content)

        _ = CisumBuilder.assembleMainView(kernel: kernel)

        #expect(root.controlView != nil)
        #expect(root.contentView != nil)
        #expect(!control.isDemoMode)
        #expect(!content.isDemoMode)
        #expect(content.tabs.isEmpty)
    }

    @Test
    func kernelLoadsThemeContributionsAfterPluginStartup() async throws {
        let kernel = try await CisumBuilder.createKernel()
        let theme = try #require(kernel.resolveProvider((any ThemeProviding).self))
        // Cisum 只加载白名单内的目录主题（见 `CisumThemeSelection`），
        // 加上 ProviderTheme 内置的三个基础外观。
        #expect(theme.themes.count == CisumThemeSelection.catalogueIDs.count + 3)
        #expect(theme.selectedThemeId != nil)
        try await kernel.stopAsync()
        CisumBuilder.destroyKernel(kernel)
    }

    @Test
    func kernelLoadsOnlyWhitelistedCatalogueThemes() async throws {
        let kernel = try await CisumBuilder.createKernel()
        let theme = try #require(kernel.resolveProvider((any ThemeProviding).self))

        let catalogueIDs = Set(CisumThemeSelection.catalogueIDs)
        let loaded = theme.themes.filter { catalogueIDs.contains($0.id) }
        #expect(Set(loaded.map(\.id)) == catalogueIDs)

        // 白名单外的目录主题不应出现在可选列表中。
        #expect(!theme.themes.contains { $0.id == "dracula" })
        #expect(!theme.themes.contains { $0.id == "github" })

        try await kernel.stopAsync()
        CisumBuilder.destroyKernel(kernel)
    }

    @Test
    func kernelExposesCloudDownloadProgressProvider() async throws {
        let kernel = try await CisumBuilder.createKernel()
        let download = try #require(kernel.resolveProvider((any CloudDownloadProviding).self))

        // A plain local file is not iCloud-backed, so the provider must
        // report it as complete rather than as a pending download.
        #expect(download.progress(for: URL(fileURLWithPath: "/tmp")) == 1)

        try await kernel.stopAsync()
        CisumBuilder.destroyKernel(kernel)
    }

    @Test
    func kernelExposesSharedThemeSettingsNavigationItem() async throws {
        let kernel = try await CisumBuilder.createKernel()
        let settings = try #require(kernel.resolveProvider((any SettingViewProviding).self))

        #expect(settings.entries.contains { $0.id == "appearance" })

        try await kernel.stopAsync()
        CisumBuilder.destroyKernel(kernel)
    }
}
