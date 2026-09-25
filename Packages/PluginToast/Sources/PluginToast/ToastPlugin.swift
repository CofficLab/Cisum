import ProviderRootView
import ProviderToast
import CisumKernelSupport
import MagicKit

@MainActor
public final class ToastPlugin: SuperPlugin {
    public let id = String(describing: ToastPlugin.self)

    public static let shared = ToastPlugin()
        public let order = 10
    public let iconName = "bell.badge"
    public let metadata = PluginMetadata(
        id: String(describing: ToastPlugin.self),
        name: "Toast",
        description: "Global messages, loading state, and error notices.",
        version: "1.0.0",
        category: .core,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )
    public let center = ToastProvider()
    private static let overlayID = "cisum.toast"

    public init() {}

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        kernel.unregisterProvider((any ToastProviding).self)
        try kernel.registerProvider((any ToastProviding).self, center)
        CisumToastBridge.install(center)

        kernel.resolveProvider((any RootViewProviding).self)?.addOverlays([
            RootOverlayItem(id: Self.overlayID, order: 10_000) { content in
                ToastOverlay(content: content, center: self.center)
            }
        ])
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        center.dismissAll()
        kernel.resolveProvider((any RootViewProviding).self)?.removeOverlays(ids: [Self.overlayID])
        CisumToastBridge.install(DefaultToastProvider())
    }
}