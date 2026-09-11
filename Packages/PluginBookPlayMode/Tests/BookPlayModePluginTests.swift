import MagicPlayMan
import Testing
@testable import PluginBookPlayMode

@Test func pluginInfoExportsRegistrationMetadata() {
    #expect(BookPlayModePluginInfo.iconName == "repeat")
    #expect(BookPlayModePluginInfo.order == 7)
}

@Test func bookPlayModeFallsBackToCloudWhenLocalValueIsInvalid() {
    #expect(BookPlayModeStore.resolvedPlayMode(
        localRawValue: "invalid",
        cloudRawValue: MagicPlayMode.loop.rawValue
    ) == .loop)
}

@Test func bookPlayModeDefaultsWhenStoredValuesAreInvalid() {
    #expect(BookPlayModeStore.resolvedPlayMode(
        localRawValue: "invalid",
        cloudRawValue: "also-invalid"
    ) == .sequence)
}
