import ProviderDocsView
import KernelCore
import CisumUIComponents
import LumiUI
import ProviderPluginManaging
import ProviderPluginControl
import ProviderPlugin
import ProviderStorage
import ProviderSettingView
import SwiftUI

/// 插件管理插件（对齐 Lumi `PluginPluginManager`）。
///
/// 在设置窗口注册「插件管理」导航入口（puzzlepiece.extension，order 90），
/// 详情展示所有可配置插件的列表 + 分类筛选 + 启停开关，并展示每个插件
/// 贡献的 about 视图（未贡献时回退默认 about）。onBoot 保存内核引用，
/// 供 `makeSettingEntry()` 构造 `PluginManaging` 数据源；自身也在
/// `onRegister` 中贡献关于页与说明书。
@MainActor
public final class PluginPluginManager: AsyncSuperPlugin {
    public let id = String(describing: PluginPluginManager.self)

    public static let shared = PluginPluginManager()
    public static let pluginID = "com.coffic.cisum.plugin.plugin-manager"
    public let order = 90
    public let iconName = "puzzlepiece.extension"
    public let metadata = PluginMetadata(
        id: pluginID,
        name: String(localized: "Plugin Manager", bundle: .module),
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .disabled,
        permissions: []
    )

    /// 设置导航项稳定 ID。
    static let settingsEntryID = "plugin-manager"

    /// onBoot 时保存的内核引用，用于构建插件管理数据源。
    ///
    /// 仅在主线程访问（onBoot / makeSettingEntry 均 @MainActor）。
    nonisolated(unsafe) private var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var managementManager: (any PluginManaging)?
    nonisolated(unsafe) private var managementViewModel: PluginManagementViewModel?
    nonisolated(unsafe) private var managementObserver: PluginManagerObserver?

    public init() {}

    /// 在 `onRegister` 贡献自身文档（关于页 + 说明书）。
    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) {
                PluginManagerAboutView()
            })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) {
                PluginManagerManualView()
            })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        try installState(kernel: kernel)

        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingView() { contrib.addSettingView(ownerPluginID: id, view) }
            if let entry = makeSettingEntry() { kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([entry]) }
        }
        // 注入插件启用状态持久化存储：onBoot 阶段从内核的 StorageProviding
        // 解析插件专属数据目录（目录名 = 插件 ID，对齐 GitOK 规律）。
        // 本插件为 alwaysOn，先于所有可配置插件的启用判断完成注入。
        if let storage = kernel.resolveProvider((any ProviderStorage.StorageProviding).self) {
            let pluginDir = storage.pluginDataDirectory(for: Self.pluginID)
            kernel.stateStore = PluginEnabledStateStore(pluginDirectory: pluginDir)
        }

    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [Self.settingsEntryID])
        if let managementManager,
           kernel.resolveProvider((any PluginManaging).self) === managementManager {
            kernel.unregisterProvider((any PluginManaging).self)
        }
        teardownState()
    }

    @MainActor
    public func addSettingView() -> AnyView? {
        nil
    }

    @MainActor
    public func makeSettingEntry() -> SettingEntryItem? {
        guard let kernel else { return nil }
        try? installState(kernel: kernel)
        let viewModel = resolveViewModel()
        return SettingEntryItem(
            id: Self.settingsEntryID,
            title: String(localized: "Plugin Manager", bundle: .module),
            systemImage: iconName,
            order: order,
            detail: {
            PluginManagementView(docsProvider: self.kernel?.resolveProvider((any DocsViewProviding).self), viewModel: viewModel)
        }
        )
    }

    // MARK: - State assembly

    @MainActor
    private func installState(kernel: KernelCoreContainer) throws {
        guard managementViewModel == nil else { return }
        // 远程三件套（对齐 Lumi Factory 装配：DefaultPluginControlling /
        // DefaultPluginManager / PluginEnabledStateStore）
        try kernel.registerProvider((any PluginControlling).self, DefaultPluginControlling(kernel: kernel))
        let controlling = kernel.resolveProvider((any PluginControlling).self)
            ?? DefaultPluginControlling(kernel: kernel)
        let manager = DefaultPluginManager(kernel: kernel, controlling: controlling)
        try kernel.registerProvider((any PluginManaging).self, manager)
        let viewModel = PluginManagementViewModel(manager: manager)
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
