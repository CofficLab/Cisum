import KernelCore
import SwiftUI
import Testing
@testable import ProviderPlugin

@MainActor
private final class ContributionTestPlugin: SuperPlugin {
    let id = "contribution-test-plugin"
    let metadata = PluginMetadata(id: "contribution-test-plugin")
}

@MainActor
@Test
func explicitOwnerContributionsAreVisibleAndRemoved() throws {
    let kernel = KernelCoreContainer()
    try kernel.start(plugins: [ContributionTestPlugin()])
    let service = PluginContributionService(kernel: kernel)
    let item = PluginSettingNavigationItem(
        id: "contribution-test.settings",
        title: "Contribution Test",
        iconName: "gearshape",
        order: 10,
        destination: AnyView(EmptyView())
    )

    service.addSettingNavigationItem(ownerPluginID: "contribution-test-plugin", item)
    #expect(service.getSettingNavigationItems().map(\.id) == [item.id])

    service.remove(owner: "contribution-test-plugin")
    #expect(service.getSettingNavigationItems().isEmpty)
}
