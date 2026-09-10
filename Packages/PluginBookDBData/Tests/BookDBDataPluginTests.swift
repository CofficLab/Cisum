import Testing
@testable import PluginBookDBData

@Test func bookDBDataPluginMetadataDescribesDataLayer() {
    #expect(BookDBDataPlugin.metadata.order == 11)
    #expect(BookDBDataPlugin.metadata.category == .library)
    #expect(BookDBDataPlugin.metadata.iconName == "externaldrive.badge.timemachine")
}
