import MagicKit
import Foundation
import ProviderDocsView
import CisumProviderStorage
import KernelCore
import ProviderPlugin
import CisumUIComponents
import LumiUI
import OSLog
import ProviderStorage
import SwiftUI

@MainActor
public final class StoragePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: StoragePlugin.self)

    public static let shared = StoragePlugin()
    public nonisolated static let emoji = "💾"
    public static let verbose = false
    public let order = 10
    public let iconName = StoragePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: String(describing: StoragePlugin.self),
        name: String(localized: String.LocalizationValue(StoragePluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(StoragePluginInfo.descriptionKey), bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) var settingsViewModel: StorageSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: StorageProvidingObserver?

    public init() {}

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { StoragePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { StoragePluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(ownerPluginID: id, view) }
        }
        let provider = StorageProvider(userDefaults: Self.storageDefaults())
        // Keep one concrete service as the source of truth while exposing both
        // the Cisum storage-location contract and Lumi's shared storage
        // contract. This lets shared Lumi plugins resolve ProviderStorage
        // without creating a second data root.
        try kernel.registerProvider((any CisumProviderStorage.StorageProviding).self, provider)
        try kernel.registerProvider((any ProviderStorage.StorageProviding).self, provider)

        // 插件启用状态持久化存储由 PluginPluginManager.onBoot 注入
        // （解析 kernel.resolveProvider((any CisumProviderStorage.StorageProviding).self)
        // 的根目录，写入 `<databaseRoot>/PluginManager/`）。

        installSettingsState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        installSettingsState(kernel: kernel)
    }

    /// UI tests use a private preferences suite so onboarding tests never reset
    /// or overwrite the developer's real Debug-app storage selection.
    private static func storageDefaults() -> UserDefaults {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("--cisum-ui-testing") else { return .standard }

            let suiteName = "\(Bundle.main.bundleIdentifier ?? "com.yueyi.cisum").ui-testing"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            if arguments.contains("--cisum-ui-testing-reset-storage") {
                defaults.removeObject(forKey: "StorageLocation")
            }
            if arguments.contains("--cisum-ui-testing-storage-local") {
                defaults.set(StorageLocation.local.rawValue, forKey: "StorageLocation")
            }
            return defaults
        #else
            return .standard
        #endif
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownSettingsState()
    }

    /// 内核关闭时清空静态引用，避免卸载后残留对内核生命周期服务的持有。
    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        teardownSettingsState()
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        // View 贡献可能在插件启动前被请求：保证返回一个稳定、长期存在的
        // ViewModel，而不是每次请求都重新创建。
        let viewModel = settingsViewModel ?? {
            let viewModel = StorageSettingsViewModel(
                storageProvider: nil
            )
            settingsViewModel = viewModel
            return viewModel
        }()
        return PluginSettingNavigationItem(
            id: "storage",
            title: String(localized: String.LocalizationValue(StoragePluginInfo.titleKey), bundle: .module),
            description: metadata.description,
            iconName: StoragePluginInfo.iconName,
            order: 10,
            destination: AnyView(
                StorageSettingView(
                    viewModel: viewModel,
                )
            )
        )
    }

    // MARK: - Settings state assembly

    @MainActor
    private func installSettingsState(kernel: KernelCoreContainer) {
        guard let storage = kernel.resolveProvider((any CisumProviderStorage.StorageProviding).self) else { return }
        installSettingsState(storage: storage)
    }

    /// Binds the stable settings ViewModel to the storage service once it becomes available.
    /// Navigation contributions may be requested before `onBoot`, so the initial model can
    /// legitimately exist without a capability.
    @MainActor
    func installSettingsState(storage: any CisumProviderStorage.StorageProviding) {
        let viewModel = settingsViewModel ?? StorageSettingsViewModel(storageProvider: storage)
        viewModel.updateStorageProvider(storage)

        settingsObserver?.cancel()
        settingsObserver = StorageProvidingObserver(provider: storage, viewModel: viewModel)
        settingsViewModel = viewModel
    }

    @MainActor
    private func teardownSettingsState() {
        settingsObserver?.cancel()
        settingsObserver = nil
        settingsViewModel = nil
    }

}
