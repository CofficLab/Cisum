import MagicKit
import Foundation
import ProviderDocsView
import CisumProviderStorage
import KernelCore
import ProviderPlugin
import LumiUI
import OSLog
import ProviderStorage
import ProviderSettingView
import SwiftUI

@MainActor
public final class StoragePlugin: AsyncSuperPlugin, SuperLog {
    /// 插件 id。
    ///
    /// 同时是本插件数据目录的目录名——存储位置的配置文件落在
    /// `<databaseRoot>/com.coffic.cisum.plugin.storage/storage-location.json`。
    public static let pluginID = "com.coffic.cisum.plugin.storage"

    public let id = StoragePlugin.pluginID

    public static let shared = StoragePlugin()
    public nonisolated static let emoji = "💾"
    public static let verbose = false
    public let order = 10
    public let iconName = StoragePluginInfo.iconName
    public let metadata = PluginMetadata(
        id: "com.coffic.cisum.plugin.storage",
        name: String(localized: String.LocalizationValue(StoragePluginInfo.titleKey), bundle: .module),
        version: "1.0.0",
        category: .feature,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) var settingsViewModel: StorageSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: StorageProvidingObserver?
    /// 设置页消费的存储能力。ViewModel 以 `weak` 持有 Adapter，
    /// 故此处必须显式强持有，否则能力会随 `installSettingsState` 返回而释放。
    nonisolated(unsafe) private var settingsCapability: StorageSettingsCapabilityAdapter?

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
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
        }
        let provider = StorageProvider()
        // Keep one concrete service as the source of truth while exposing both
        // the Cisum storage-location contract and Lumi's shared storage
        // contract. This lets shared Lumi plugins resolve ProviderStorage
        // without creating a second data root.
        try kernel.registerProvider((any CisumProviderStorage.StorageProviding).self, provider)
        try kernel.registerProvider((any ProviderStorage.StorageProviding).self, provider)

        // UI 测试需要在启动时钉死存储位置（重置 / 指定 local / 指定 iCloud）。
        // 配置已改为落盘，因此这里直接写磁盘文件，而不是操纵偏好域。
        Self.applyUITestStorageOverridesIfNeeded(provider: provider)

        // 插件启用状态的持久化存储在此注入（对齐 Lumi `FactoryLumi`）。
        //
        // 为什么放在这里而不是 PluginPluginManager：那个插件自身的策略是
        // `.disabled`（彻底停用，不注册不启动），它的 `onBoot` 默认不会执行——
        // 状态存储因此永远不会被注入，「用户关掉的插件」重启后又变回默认。
        //
        // 本插件是 `.alwaysOn` 且 order 最小，必然 boot；且它持有数据根目录，
        // 由它来准备状态存储的落盘位置最自然。
        installEnabledStateStore(kernel: kernel, storage: provider)

        installSettingsState(kernel: kernel)
    }

    /// 准备插件启用状态的持久化存储。
    ///
    /// 状态文件落在**插件管理器**的专属目录里（目录名 = 插件 id），
    /// 与 Lumi 的布局一致。迁移同样在这里完成：插件管理器默认不启动，
    /// 不能指望它自己搬运旧目录。
    private func installEnabledStateStore(
        kernel: KernelCoreContainer,
        storage: any ProviderStorage.StorageProviding
    ) {
        let pluginManagerID = "com.coffic.cisum.plugin.plugin-manager"
        let dataRoot = storage.dataRootDirectory
        let currentDirectory = dataRoot.appendingPathComponent(pluginManagerID, isDirectory: true)

        // 迁移历史目录。必须先迁移、再创建目录——`pluginDataDirectory(for:)`
        // 会创建目录，若先用它拿到目标路径，「目标不存在」的判断恒为真，
        // 迁移就永远不会执行。
        for legacyName in PluginDataDirectoryHistory.legacyDirectoryNames(for: pluginManagerID) {
            let legacyDirectory = dataRoot.appendingPathComponent(legacyName, isDirectory: true)
            if PluginDataDirectoryMigration.migrate(from: legacyDirectory, to: currentDirectory) {
                break
            }
        }

        kernel.stateStore = PluginEnabledStateStore(
            pluginDirectory: storage.pluginDataDirectory(for: pluginManagerID)
        )
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        installSettingsState(kernel: kernel)
    }

    /// 按 UI 测试的启动参数覆写存储位置配置。
    ///
    /// 配置已改为落盘（`<dataRoot>/<pluginID>/storage-location.json`），
    /// 因此这里直接改磁盘文件，不再操纵偏好域。
    ///
    /// - Important: UI 测试的数据根本身已由 `UITestIsolation` 隔离到临时目录，
    ///   覆写不会碰到开发者真实沙盒里的配置文件。
    ///
    /// - Note: iCloud 与本地路径走的是完全不同的目录监控实现
    ///   （`NSMetadataQuery` vs `DispatchSource`），且 iCloud 容器在无 iCloud
    ///   账号或容器不可用时会退化为 nil。用例需要显式钉住这一分支，
    ///   否则「有声书仓库一直显示正在读取」这类缺陷只在真实配置下出现。
    @MainActor
    private static func applyUITestStorageOverridesIfNeeded(provider: StorageProvider) {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("--cisum-ui-testing") else { return }

            if arguments.contains("--cisum-ui-testing-reset-storage") {
                provider.resetStorageLocation()
            }
            if arguments.contains("--cisum-ui-testing-storage-local") {
                provider.setStorageLocation(.local)
            }
            if arguments.contains("--cisum-ui-testing-storage-icloud") {
                provider.setStorageLocation(.icloud)
            }
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
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["storage"])
        teardownSettingsState()
    }

    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        // View 贡献可能在插件启动前被请求：保证返回一个稳定、长期存在的
        // ViewModel，而不是每次请求都重新创建。
        let viewModel = settingsViewModel ?? {
            let viewModel = StorageSettingsViewModel(storage: nil)
            settingsViewModel = viewModel
            return viewModel
        }()
        return SettingEntryItem(
            id: "storage",
            title: String(localized: String.LocalizationValue(StoragePluginInfo.titleKey), bundle: .module),
            systemImage: StoragePluginInfo.iconName,
            order: 10,
            detail: {
            StorageSettingView(
                                viewModel: viewModel,
                            )
        }
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
        let capability = StorageSettingsCapabilityAdapter(storage: storage)
        settingsCapability = capability
        let viewModel = settingsViewModel ?? StorageSettingsViewModel(storage: capability)
        viewModel.updateStorage(capability)

        settingsObserver?.cancel()
        settingsObserver = StorageProvidingObserver(storage: capability, viewModel: viewModel)
        settingsViewModel = viewModel
    }

    @MainActor
    private func teardownSettingsState() {
        settingsObserver?.cancel()
        settingsObserver = nil
        settingsViewModel = nil
        settingsCapability = nil
    }

}
