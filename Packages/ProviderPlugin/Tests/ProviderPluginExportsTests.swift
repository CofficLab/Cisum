import Testing
import ProviderPlugin

@Test
func reexportsKernelPluginContracts() {
    let metadata = PluginMetadata(
        displayName: "Compatibility facade",
        description: "Verifies the legacy import path exposes KernelCore contracts.",
        policy: .alwaysOn
    )

    #expect(metadata.displayName == "Compatibility facade")
    #expect(metadata.policy == .alwaysOn)
}
