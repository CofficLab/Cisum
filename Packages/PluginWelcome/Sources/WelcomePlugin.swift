import CisumKernel
import ProviderDocsView
import CisumUIComponents
import ProviderStorage
import SwiftUI

public actor WelcomePlugin: SuperPlugin, SuperLog {
    public static let shared = WelcomePlugin()
    public nonisolated static let emoji = WelcomePluginInfo.emoji
    public static let verbose = false
    public static let metadata = PluginMetadata(
        displayName: WelcomePluginInfo.title,
        description: WelcomePluginInfo.description,
        iconName: WelcomePluginInfo.iconName,
        order: WelcomePluginInfo.order,
        category: .tool,
    )


    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { WelcomePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { WelcomePluginManualView() })
        }
    }

    /// OnReady 阶段注入的存储能力。`WelcomePluginHost` 的闭包为 `@Sendable`，
    /// 因此通过 `nonisolated(unsafe) static` 持有，避免捕获非 Sendable 的实例。
    nonisolated(unsafe) static var storage: (any StorageProviding)?

    /// OnReady 阶段（Storage 服务已注册）将 `WelcomePluginHost` 桥接到内核
    /// `StorageProviding`。
    @MainActor
    public func onReady(kernel: CisumKernel) async throws {
        guard let storage = kernel.storage else { return }
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
