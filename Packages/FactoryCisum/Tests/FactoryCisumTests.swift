import FactoryCisum
import KernelCore
import ProviderContentView
import ProviderControlView
import ProviderRootView
import Testing

@MainActor
struct FactoryCisumTests {
    @Test
    func defaultPluginFactoryProducesUniquePluginIDs() {
        let plugins = DefaultPluginFactory().makePlugins()
        let ids = plugins.map(\.id)

        #expect(ids.count > 40)
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
        let view = CisumBuilder.assembleMainView(kernel: CisumKernel())
        _ = view
    }

    @Test
    func mainViewAssemblyInjectsControlAndContentProviders() throws {
        let kernel = CisumKernel()
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
}
