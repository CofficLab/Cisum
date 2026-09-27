import SwiftUI
import Testing
import ProviderPlugin

@Test
func pluginSettingNavigationItemCarriesPluginOwnedPresentationData() {
    let item = PluginSettingNavigationItem(
        id: "plugin.settings",
        title: "Settings",
        description: "Plugin preferences",
        iconName: "gearshape",
        order: 10,
        destination: AnyView(EmptyView())
    )

    #expect(item.id == "plugin.settings")
    #expect(item.title == "Settings")
    #expect(item.order == 10)
}
