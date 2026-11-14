import PluginAudioScene
import Testing

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(AudioScenePluginInfo.iconName == "music.note.list")
    #expect(AudioScenePluginInfo.order == 0)
}
