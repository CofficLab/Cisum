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
