import KernelCore
import ProviderRootView

/// Registers Cisum's player root provider through the Kernel plugin lifecycle.
@MainActor
public final class CisumRootViewPlugin: SuperPlugin {
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

    private var provider: CisumRootViewProvider?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let provider = CisumRootViewProvider(kernel: kernel)
        kernel.unregisterProvider((any RootViewProviding).self)
        try kernel.registerProvider((any RootViewProviding).self, provider)
        self.provider = provider
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any RootViewProviding).self)
        provider = nil
    }
}
