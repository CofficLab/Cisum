import KernelCore
import SwiftUI
import Testing
@testable import ProviderPlugin

@MainActor
private final class ContributionTestPlugin: SuperPlugin {
    let id = "contribution-test-plugin"
    let metadata = PluginMetadata(id: "contribution-test-plugin")
}

