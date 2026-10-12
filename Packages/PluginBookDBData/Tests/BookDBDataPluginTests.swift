import Testing
@testable import PluginBookDBData

@Test @MainActor func bookDBDataPluginMetadataDescribesDataLayer() {
    #expect(BookDBDataPlugin().order == 11)
    #expect(BookDBDataPlugin().metadata.category == .feature)
    #expect(BookDBDataPlugin().iconName == "externaldrive.badge.timemachine")
}
