import ProviderDocsView
import ProviderStorage
import CisumKernelSupport
import CisumUIComponents
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
        policy: .disabled,
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
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addGuideView() { contrib.addGuideView(view) }
        }
    }

    /// OnReady 阶段注入的存储能力。`WelcomePluginHost` 的闭包为 `@Sendable`，
    /// 因此通过 `nonisolated(unsafe) static` 持有，避免捕获非 Sendable 的实例。
    nonisolated(unsafe) static var storage: (any StorageProviding)?

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