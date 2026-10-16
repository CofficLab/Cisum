import ProviderDocsView
import CisumProviderStorage
import KernelCore
import ProviderPlugin
import ProviderRootView
import KitAppEvents
import MagicKit
import LumiUI
import SwiftUI

@MainActor
public final class WelcomePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: WelcomePlugin.self)

    public static let shared = WelcomePlugin()
    public nonisolated static let emoji = WelcomePluginInfo.emoji
    public static let verbose = false
    public let order = WelcomePluginInfo.order
    public let iconName = WelcomePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: WelcomePlugin.self),
        name: WelcomePluginInfo.title,
        description: WelcomePluginInfo.description,
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )


    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { WelcomePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { WelcomePluginManualView() })
        }
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        kernel.resolveProvider((any RootViewProviding).self)?.removeOverlays(ids: [Self.storageSetupOverlayID])
        // 引导不再存在，必须归还工具栏，否则根视图会一直停在无工具栏态。
        welcomeRootChromeCapability?.restoreIfNeeded()
        welcomeRootChromeCapability = nil
        welcomeStorageCapability = nil
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        // Storage is registered by StoragePlugin during onBoot. The actual
        // onboarding overlay is installed in onReady, after all providers exist.
    }

    /// OnReady 阶段注入的存储能力。`WelcomePluginHost` 的闭包为 `@Sendable`，
    /// 因此通过 `nonisolated(unsafe) static` 持有，避免捕获非 Sendable 的实例。
    nonisolated(unsafe) static var storage: (any StorageProviding)?
    private static let storageSetupOverlayID = "cisum.welcome.storage-setup"

    /// 本插件消费的能力 Adapter。Overlay 的 StateObject 强持有能力，
    /// 入口同样持有以满足组装层所有权约定（Capabilities 规范第 5 条）。
    nonisolated(unsafe) private var welcomeStorageCapability: WelcomeStorageCapabilityAdapter?

    /// 根视图外观能力（引导期抑制工具栏）。入口强持有以满足组装层所有权约定
    /// （Capabilities 规范第 5 条）：Overlay 只经能力写状态，不直接持有适配器。
    nonisolated(unsafe) private var welcomeRootChromeCapability: WelcomeRootChromeCapabilityAdapter?

    /// OnReady 阶段（Storage 服务已注册）将 `WelcomePluginHost` 桥接到内核
    /// `StorageProviding`。
    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        Self.storage = storage
        WelcomePluginHost.configure(
            hasStorageLocation: { Self.storage?.hasUsableStorageLocation ?? false },
            isICloudAvailable: { Self.storage?.isICloudStorageAvailable ?? false },
            currentStorageSelection: {
                guard let location = Self.storage?.currentStorageLocation else { return nil }
                return WelcomeStorageSelection(rawValue: location.rawValue)
            },
            updateStorageSelection: { selection in
                Self.storage?.setStorageLocation(StorageLocation(rawValue: selection.rawValue))
            }
        )

        guard let root = kernel.resolveProvider((any RootViewProviding).self) else { return }
        root.addOverlays([
            RootOverlayItem(id: Self.storageSetupOverlayID, order: 9_000) { content in
                WelcomeStorageSetupOverlay(
                    storage: self.welcomeStorageCapability(for: storage),
                    chrome: self.welcomeRootChromeCapability(for: root),
                    content: content
                )
            }
        ])
    }

    /// 组装欢迎页存储能力（幂等）：入口持有，Overlay 经能力消费存储。
    @MainActor
    private func welcomeStorageCapability(
        for storage: (any StorageProviding)?
    ) -> WelcomeStorageCapabilityAdapter {
        if let welcomeStorageCapability { return welcomeStorageCapability }
        let capability = WelcomeStorageCapabilityAdapter(storage: storage)
        welcomeStorageCapability = capability
        return capability
    }

    /// 组装根视图外观能力（幂等）：入口持有，Overlay 经能力抑制/恢复工具栏。
    @MainActor
    private func welcomeRootChromeCapability(
        for root: any RootViewProviding
    ) -> WelcomeRootChromeCapabilityAdapter {
        if let welcomeRootChromeCapability { return welcomeRootChromeCapability }
        let capability = WelcomeRootChromeCapabilityAdapter(root: root)
        welcomeRootChromeCapability = capability
        return capability
    }

    @MainActor
    public func addGuideView() -> AnyView? {
        guard WelcomePluginHost.hasStorageLocation == false else {
            return nil
        }

        return AnyView(WelcomePluginGuideView())
    }

    @MainActor
    public func completeGuidePage() -> Bool {
        guard WelcomePluginHost.hasStorageLocation == false else {
            return true
        }

        let selection = WelcomeStorageSelectionPolicy.defaultSelection(
            currentStorageSelection: WelcomePluginHost.currentStorageSelection,
            isICloudAvailable: WelcomePluginHost.isICloudAvailable
        )
        WelcomePluginHost.updateStorageSelection(selection)
        return true
    }
}
