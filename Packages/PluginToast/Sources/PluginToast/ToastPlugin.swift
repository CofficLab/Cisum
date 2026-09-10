import KernelCore
import MagicKit
import ProviderRootView
import ProviderToast

public actor ToastPlugin: SuperPlugin {
    public static let shared = ToastPlugin()
    public static let metadata = PluginMetadata(
        displayName: "Toast",
        description: "Global messages, loading state, and error notices.",
        iconName: "bell.badge",
        order: 10,
        policy: .alwaysOn,
        category: .core
    )

    public let center = ToastProvider()
    private static let overlayID = "cisum.toast"

    public init() {}

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        kernel.unregisterProvider((any ToastProviding).self)
        kernel.registerProvider((any ToastProviding).self, center)
        CisumToastBridge.install(center)

        kernel.resolveProvider((any RootViewProviding).self)?.addOverlays([
            RootOverlayItem(id: Self.overlayID, order: 10_000) { content in
                ToastOverlay(content: content, center: self.center)
            }
        ])
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        center.dismissAll()
        kernel.resolveProvider((any RootViewProviding).self)?.removeOverlays(ids: [Self.overlayID])
        CisumToastBridge.install(DefaultToastProvider())
    }
}
