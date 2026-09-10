import KernelCore
import ProviderDocsView
import CisumUIComponents
import OSLog
import ProviderStorage
import SwiftUI

public actor StoragePlugin: SuperPlugin, SuperLog {
    public static let shared = StoragePlugin()
    public nonisolated static let emoji = "💾"
    public static let verbose = false
    public static let metadata = PluginMetadata(
        displayName: String(localized: String.LocalizationValue(StoragePluginInfo.titleKey), bundle: .module),
        description: String(localized: String.LocalizationValue(StoragePluginInfo.descriptionKey), bundle: .module),
        iconName: StoragePluginInfo.iconName,
        order: 10,
        policy: .alwaysOn,
        category: .library,
    )

    nonisolated(unsafe) private var settingsViewModel: StorageSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: StorageProvidingObserver?

    public init() {}

    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) { StoragePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) { StoragePluginManualView() })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        let provider = StorageProvider()
        StorageProvider.current = provider
        kernel.registerStorage(provider)

        // 插件启用状态持久化存储由 PluginPluginManager.onBoot 注入
        // （解析 kernel.storage 的根目录，写入 `<databaseRoot>/PluginManager/`）。

        installSettingsState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: CisumKernel) async throws {
        installSettingsState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: CisumKernel) async throws {
        teardownSettingsState()
    }

    /// 内核关闭时清空静态引用，避免卸载后残留对内核生命周期服务的持有。
    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
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
            description: Self.metadata.description,
            iconName: StoragePluginInfo.iconName,
            order: 10,
            destination: AnyView(
                StorageSettingView(viewModel: viewModel)
                    .pluginStorageDependencies(StorageProvider.makePluginDependencies())
            )
        )
    }

    // MARK: - Settings state assembly

    @MainActor
    private func installSettingsState(kernel: CisumKernel) {
        guard settingsViewModel == nil else { return }
        guard let storage = kernel.storage else { return }
        let viewModel = StorageSettingsViewModel(
            capability: makeStorageCapability(from: storage)
        )
        let observer = StorageProvidingObserver(provider: storage, viewModel: viewModel)
        settingsViewModel = viewModel
        settingsObserver = observer
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
