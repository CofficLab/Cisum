import PluginBookScene
import Testing

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(BookScenePluginInfo.iconName == "book.closed")
    #expect(BookScenePluginInfo.order == 0)
}
