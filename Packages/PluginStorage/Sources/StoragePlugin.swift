import ProviderDocsView
import ProviderStorage
import CisumKernelSupport
import CisumUIComponents
import OSLog
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
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(view) }
        }
        let provider = StorageProvider()
        StorageProvider.current = provider
        try kernel.registerProvider((any StorageProviding).self, provider)

        // 插件启用状态持久化存储由 PluginPluginManager.onBoot 注入
        // （解析 kernel.resolveProvider((any StorageProviding).self) 的根目录，写入 `<databaseRoot>/PluginManager/`）。

        installSettingsState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        installSettingsState(kernel: kernel)
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
        StorageProvider.current = nil
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        // View 贡献可能在插件启动前被请求：保证返回一个稳定、长期存在的
        // ViewModel，而不是每次请求都重新创建。
        let viewModel = settingsViewModel ?? {
            let viewModel = StorageSettingsViewModel(
                capability: makeStorageCapability(from: StorageProvider.current)
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
                    dependencies: StorageProvider.makePluginDependencies()
                )
            )
        )
    }

    // MARK: - Settings state assembly

    @MainActor
    private func installSettingsState(kernel: KernelCoreContainer) {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else { return }
        installSettingsState(storage: storage)
    }

    /// Binds the stable settings ViewModel to the storage service once it becomes available.
    /// Navigation contributions may be requested before `onBoot`, so the initial model can
    /// legitimately exist without a capability.
    @MainActor
    func installSettingsState(storage: any StorageProviding) {
        let viewModel = settingsViewModel ?? StorageSettingsViewModel(capability: nil)
        viewModel.updateCapability(makeStorageCapability(from: storage))

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

    @MainActor
    private func makeStorageCapability(
        from storage: (any StorageProviding)?
    ) -> (any StorageSettingsCapability)? {
        guard let storage else { return nil }
        return StorageSettingsCapabilityAdapter(storage: storage)
    }
}