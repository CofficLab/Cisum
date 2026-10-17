import Testing
@testable import PluginAudioDemo

@Test func pluginMetadataIsStable() {
    #expect(AudioDemoPluginInfo.iconName == "externaldrive")
    #expect(!AudioDemoPluginInfo.title.isEmpty)
    #expect(!AudioDemoPluginInfo.description.isEmpty)
    #expect(!AudioDemoPluginInfo.tabLabel.isEmpty)
}

@MainActor
@Test func demoAudioFilesAreAvailable() {
    #expect(AudioListDemo.demoAudioFiles.count == 20)
    #expect(AudioItemDemo.iconNames.count == 8)
}

@Test func audioDemoStableIndexHandlesExtremeHashes() {
    #expect(AudioItemDemo.stableIndex(for: Int.min, count: 8) >= 0)
    #expect(AudioItemDemo.stableIndex(for: Int.min, count: 8) < 8)
    #expect(AudioItemDemo.stableIndex(for: -1, count: 8) == 7)
    #expect(AudioItemDemo.stableIndex(for: 9, count: 8) == 1)
    #expect(AudioItemDemo.stableIndex(for: 1, count: 0) == 0)
}

@MainActor
@Test func audioDemoPluginExposesStableIdentityAndMetadata() {
    let plugin = AudioDemoPlugin.shared

    #expect(plugin.id == "AudioDemoPlugin")
    #expect(plugin.order == 1)
    #expect(plugin.iconName == "externaldrive")
    #expect(plugin.metadata.id == "AudioDemoPlugin")
    #expect(plugin.metadata.name == "Audio Repository")
    #expect(plugin.metadata.description == "Audio file database view")
    #expect(plugin.metadata.version == "1.0.0")
    #expect(plugin.metadata.category == .feature)
    #expect(plugin.metadata.stage == .stable)
    #expect(plugin.metadata.policy == .disabled)
    #expect(plugin.metadata.permissions.isEmpty)
}
