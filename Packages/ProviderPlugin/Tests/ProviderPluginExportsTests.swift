import Testing
import ProviderPlugin

@Test
func reexportsKernelPluginContracts() {
    let metadata = PluginMetadata(
        id: "compat-facade",
        name: "Compatibility facade",
        description: "Verifies the legacy import path exposes KernelCore contracts.",
        policy: .alwaysOn
    )

    #expect(metadata.name == "Compatibility facade")
    #expect(metadata.policy == .alwaysOn)
}
