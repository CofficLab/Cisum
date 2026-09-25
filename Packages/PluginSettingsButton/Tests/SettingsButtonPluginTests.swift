import Foundation
import Testing
@testable import PluginSettingsButton

@Test @MainActor func pluginMetadataIsStable() {
    #expect(SettingsButtonPluginInfo.toolbarItemId == "settings-button")
    #expect(SettingsButtonPluginInfo.settingsWindowID == "cisum.settings")
    #expect(SettingsButtonPluginInfo.iconName == "gearshape")
    #expect(!SettingsButtonPluginInfo.description.isEmpty)
    #expect(SettingsButtonView.title == "Settings")
}

@Test @MainActor func pluginMetadataDescribesSettingsEntry() {
    #expect(SettingsButtonPlugin().metadata.name == "Settings")
    #expect(SettingsButtonPlugin().metadata.category == .system)
    #expect(SettingsButtonPlugin().metadata.policy == .alwaysOn)
}
