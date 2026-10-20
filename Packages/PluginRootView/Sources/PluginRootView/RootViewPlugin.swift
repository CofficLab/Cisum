import KernelCore
import ProviderRootView

/// Registers Cisum's player root provider through the Kernel plugin lifecycle.
@MainActor
public final class RootViewPlugin: SuperPlugin {
    public static let pluginID = "com.coffic.cisum.plugin.root-view"

    public let id = "com.coffic.cisum.plugin.root-view"
    public let order = 0
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.root-view",
        name: "Cisum Root View",
        description: "Provides the Cisum player layout",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    private var provider: RootViewProvider?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // Create the provider bound to this kernel instance.
        let provider = RootViewProvider(kernel: kernel)
        // Remove any previously registered root view provider to avoid a duplicate registration error.
        kernel.unregisterProvider((any RootViewProviding).self)
        // Publish the provider so the app can resolve the Cisum player layout.
        try kernel.registerProvider((any RootViewProviding).self, provider)
        // Keep a strong reference; the plugin owns the provider's lifetime and releases it on shutdown.
        self.provider = provider
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any RootViewProviding).self)
        provider = nil
    }
}
