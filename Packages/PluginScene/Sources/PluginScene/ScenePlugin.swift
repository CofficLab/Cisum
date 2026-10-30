import ProviderScene
import ProviderDocsView
import KernelCore
import ProviderPlugin
import ProviderStorage
import Foundation
import SwiftUI
import MagicKit

/// 场景 Provider 插件。
///
/// 场景为内置固定枚举（`AppScene.allCases`），本插件负责把 `SceneProvider`
/// 注册进内核并恢复上次场景；不再从已启用插件的 `addSceneItem()` 贡献中收集。
/// 同时通过 `addToolBarButtons()` 把场景切换器贡献到工具栏（迁移自
/// `ProviderToolbar` 的 `DefaultToolbarProviding`）。
///
/// 场景切换只保留工具栏入口，**不再贡献设置窗口导航项**：设置界面里
/// 不再出现「场景」入口。
///
/// 入口在 `onReady` 创建并持有长期存在的 `SceneSelectionViewModel` 与
/// `SceneProvidingObserver`；View 不自行创建状态对象、也不直接读取 Provider。
@MainActor
public final class ScenePlugin: AsyncSuperPlugin, SuperLog {
    public let id = String(describing: ScenePlugin.self)

    nonisolated static let verbose = false

    public static let shared = ScenePlugin()
    public let order = 9999
    public let iconName = "rectangle.3.group"
    public let metadata = PluginMetadata(
        id: "scene",
        name: String(localized: "Scene", bundle: .module),
        version: "1.0.0",
        category: .core,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var sceneProvider: SceneProvider?
    nonisolated(unsafe) private(set) var selectionViewModel: SceneSelectionViewModel?
    nonisolated(unsafe) private var selectionObserver: SceneProvidingObserver?

    /// 工具栏场景切换器消费的 Adapter。ViewModel 以 `weak` 持有，故入口必须
    /// 显式强持有，否则能力会随装配调用返回而释放。
    nonisolated(unsafe) private var selectionCapability: SceneSelectionCapabilityAdapter?

    public init() {}

    @MainActor
    public func onRegister(kernel: KernelCoreContainer) throws {
        self.kernel = kernel
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: self.id, name: metadata.name) { ScenePluginAboutView() })
            docs.addManual(DocsEntry(id: self.id, name: metadata.name) { ScenePluginManualView() })
        }
    }

    @MainActor
    public func onBootAsync(kernel: KernelCoreContainer) async throws {
        self.kernel = kernel
        // onBoot 阶段 StoragePlugin 可能尚未启动（ScenePlugin order=-1000 优先），
        // 先注册无持久化的 SceneProvider 保证下游插件可访问 SceneProviding。
        // 同一个实例全程存活，身份稳定，消费方弱引用不会因后续替换而失效。
        let provider = SceneProvider()
        self.sceneProvider = provider
        try kernel.registerProvider((any SceneProviding).self, provider)

        // 先设置 kernel 并注册 SceneProviding，再构建依赖它的工具栏
        // ViewModel；否则 SceneSwitcher 会永久持有空场景列表。
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            contrib.addToolBarButtons(ownerPluginID: id, self.addToolBarButtons())
        }
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        // onReady 在所有插件 onBoot 完成后执行，此时 StoragePlugin 已注入 storage。
        // 不再替换实例，只给同一个 SceneProvider 挂上持久化目录并恢复上次场景
        // （对齐 Lumi `DefaultThemeProviding.setStorageDirectory`）。
        if let storage = kernel.resolveProvider((any ProviderStorage.StorageProviding).self), let sceneProvider {
            let pluginDir = storage.pluginDataDirectory(for: self.id)
            sceneProvider.enablePersistence(pluginDataDirectory: pluginDir)
        }
        kernel.resolveProvider((any SceneProviding).self)?.restoreCurrentScene()
        installSelectionState(kernel: kernel)
    }

    @MainActor
    public func onEnable(kernel: KernelCoreContainer) async throws {
        installSelectionState(kernel: kernel)
    }

    @MainActor
    public func onDisable(kernel: KernelCoreContainer) async throws {
        teardownSelectionState()
    }

    @MainActor
    public func addToolBarButtons() -> [(id: String, view: AnyView)] {
        guard let kernel else { return [] }
        let viewModel = selectionViewModel ?? {
            let viewModel = SceneSelectionViewModel(selection: makeSelectionCapability(kernel: kernel))
            selectionViewModel = viewModel
            return viewModel
        }()
        return [(id: "scene-switcher", view: AnyView(SceneSwitcher(viewModel: viewModel)))]
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        teardownSelectionState()
        sceneProvider = nil
        kernel.unregisterProvider((any SceneProviding).self)
    }

    // MARK: - Selection state assembly

    @MainActor
    private func installSelectionState(kernel: KernelCoreContainer) {
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        let capability = makeSelectionCapability(kernel: kernel)
        let viewModel = selectionViewModel ?? SceneSelectionViewModel(selection: capability)
        // The view model may have been created during onBoot to build a toolbar
        // contribution. Attach it to the restored scene state during onReady.
        viewModel.bind(selection: capability)
        selectionViewModel = viewModel
        guard selectionObserver == nil else { return }
        selectionObserver = SceneProvidingObserver(selection: capability, viewModel: viewModel)
    }

    /// 组装场景选择能力：把内核 `SceneProviding` 收窄为工具栏切换器所需的最小能力。
    ///
    /// onBoot 阶段场景 Provider 尚未注册（本插件自己在 onReady 才恢复并替换
    /// 实例），此时能力退化为「未就绪」，ViewModel 据此隐藏场景区块；
    /// onReady 的 `installSelectionState` 会带着已就绪的能力重新绑定。
    @MainActor
    private func makeSelectionCapability(kernel: KernelCoreContainer? = nil) -> SceneSelectionCapabilityAdapter {
        if let kernel, let selectionCapability { return selectionCapability }
        let capability = SceneSelectionCapabilityAdapter(
            scene: (kernel ?? self.kernel)?.resolveProvider((any SceneProviding).self)
        )
        if kernel != nil { selectionCapability = capability }
        return capability
    }

    @MainActor
    private func teardownSelectionState() {
        selectionObserver?.cancel()
        selectionObserver = nil
        selectionViewModel = nil
        selectionCapability = nil
    }

}
