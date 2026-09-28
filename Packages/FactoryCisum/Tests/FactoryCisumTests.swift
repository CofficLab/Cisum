import ProviderControlView
import ProviderContentView
import ProviderRootView
import FactoryCisum
import KernelCore
import ProviderTheme
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
        let root = DefaultRootViewProvider(kernel: kernel)
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
        // LumiThemePack 1.0.2 exposes the canonical 19-theme catalog plus
        // the three ProviderTheme appearance variants.
        #expect(theme.themes.count == 22)
        #expect(theme.selectedThemeId != nil)
        try await kernel.stopAsync()
        CisumBuilder.destroyKernel(kernel)
    }
}
