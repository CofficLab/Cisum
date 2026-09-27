import ProviderPlayback
import MagicPlayMan
import Testing
@testable import PluginAudioPlayMode

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(AudioPlayModePluginInfo.iconName == "repeat")
    #expect(AudioPlayModePluginInfo.emoji == "🔄")
    #expect(AudioPlayModePluginInfo.order == 0)
}

@Test func audioPlayModeFallsBackToCloudWhenLocalValueIsInvalid() {
    #expect(AudioPlayModeStore.resolvedPlayMode(
        localRawValue: "invalid",
        cloudRawValue: PlaybackMode.shuffle.rawValue
    ) == .shuffle)
}

@Test func audioPlayModeDefaultsWhenStoredValuesAreInvalid() {
    #expect(AudioPlayModeStore.resolvedPlayMode(
        localRawValue: "invalid",
        cloudRawValue: "also-invalid"
    ) == .sequence)
}
