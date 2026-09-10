import KernelCore
import CisumUIComponents
import ProviderDocsView
import ProviderPluginManaging
import ProviderStorage
import SwiftUI

/// 插件管理插件（对齐 Lumi `PluginPluginManager`）。
///
/// 在设置窗口注册「插件管理」导航入口（puzzlepiece.extension，order 90），
/// 详情展示所有可配置插件的列表 + 分类筛选 + 启停开关，并展示每个插件
/// 贡献的 about 视图（未贡献时回退默认 about）。onBoot 保存内核引用，
/// 供 `addSettingNavigationItem()` 构造 `PluginManaging` 数据源；自身也在
/// `onRegister` 中贡献关于页与说明书。
public actor PluginPluginManager: SuperPlugin {
    public static let shared = PluginPluginManager()
    public static let pluginID = "com.coffic.cisum.plugin.plugin-manager"
    public static let metadata = PluginMetadata(
        id: pluginID,
        displayName: String(localized: "Plugin Manager", bundle: .module),
        description: String(localized: "Manages all registered plugins.", bundle: .module),
        iconName: "puzzlepiece.extension",
        order: 90,
        policy: .disabled,
        category: .system
    )

    /// 设置导航项稳定 ID。
    static let settingsEntryID = "plugin-manager"

    /// onBoot 时保存的内核引用，用于构建插件管理数据源。
    ///
    /// 仅在主线程访问（onBoot / addSettingNavigationItem 均 @MainActor）。
    nonisolated(unsafe) private var kernel: CisumKernel?
    nonisolated(unsafe) private var managementManager: (any PluginManaging)?
    nonisolated(unsafe) private var managementViewModel: PluginManagementViewModel?
    nonisolated(unsafe) private var managementObserver: PluginManagerObserver?

    public init() {}

    /// 在 `onRegister` 贡献自身文档（关于页 + 说明书）。
    @MainActor
    public func onRegister(kernel: CisumKernel) async throws {
        if let docs = kernel.docs {
            docs.addAbout(DocsEntry(id: self.id, name: Self.metadata.displayName) {
                PluginManagerAboutView()
            })
            docs.addManual(DocsEntry(id: self.id, name: Self.metadata.displayName) {
                PluginManagerManualView()
            })
        }
    }

    @MainActor
    public func onBoot(kernel: CisumKernel) async throws {
        self.kernel = kernel

        // 注入插件启用状态持久化存储：onBoot 阶段从内核的 StorageProviding
        // 解析插件专属数据目录（目录名 = 插件 ID，对齐 GitOK 规律）。
        // 本插件为 alwaysOn，先于所有可配置插件的启用判断完成注入。
        if let storage = kernel.storage {
            let pluginDir = storage.pluginDataDirectory(for: Self.pluginID)
            kernel.stateStore = PluginManagerStateStore(pluginDataDirectory: pluginDir)
        }

        installState(kernel: kernel)
    }

    @MainActor
    public func onShutdown(kernel: CisumKernel) async throws {
        teardownState()
    }

    @MainActor
    public func addSettingView() -> AnyView? {
        nil
    }

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        guard let kernel else { return nil }
        installState(kernel: kernel)
        let viewModel = resolveViewModel()
        return PluginSettingNavigationItem(
            id: Self.settingsEntryID,
            title: String(localized: "Plugin Manager", bundle: .module),
            description: Self.metadata.description,
            iconName: Self.metadata.iconName,
            order: Self.metadata.order,
            destination: AnyView(PluginManagementView(docsProvider: kernel.docs, viewModel: viewModel))
        )
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: CisumKernel) {
        guard managementViewModel == nil else { return }
        let manager = PluginManagerProvider(manager: kernel.pluginManager, kernel: kernel)
        let capability = PluginManagementCapabilityAdapter(manager: manager)
        let viewModel = PluginManagementViewModel(capability: capability)
        let observer = PluginManagerObserver(manager: manager, viewModel: viewModel)
        managementManager = manager
        managementViewModel = viewModel
        managementObserver = observer
    }

    @MainActor
    private func teardownState() {
        managementObserver?.cancel()
        managementObserver = nil
        managementViewModel = nil
        managementManager = nil
    }

    @MainActor
    private func resolveViewModel() -> PluginManagementViewModel {
        if let managementViewModel {
            return managementViewModel
        }
        let viewModel = PluginManagementViewModel()
        managementViewModel = viewModel
        return viewModel
    }
}
