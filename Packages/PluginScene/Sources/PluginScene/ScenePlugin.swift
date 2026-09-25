import ProviderStorage
import ProviderScene
import ProviderDocsView
import CisumKernelSupport
import CisumUIComponents
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
/// 入口在 `onReady` 创建并持有长期存在的 `SceneSettingsViewModel` 与
/// `SceneProvidingObserver`，设置导航项注入同一个 ViewModel；View 不自行创建
/// 状态对象、也不直接读取 Provider。
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
        description: String(localized: "Manages the current scene", bundle: .module),
        version: "1.0.0",
        category: .core,
        stage: .stable,
        policy: .alwaysOn,
        permissions: []
    )

    nonisolated(unsafe) private weak var kernel: KernelCoreContainer?
    nonisolated(unsafe) private var sceneProvider: SceneProvider?
    nonisolated(unsafe) private var settingsViewModel: SceneSettingsViewModel?
    nonisolated(unsafe) private var settingsObserver: SceneProvidingObserver?

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
        if let contrib = kernel.resolveProvider((any PluginContributionProviding).self) {
            if let view = self.addSettingNavigationItem() { contrib.addSettingNavigationItem(view) }
            contrib.addToolBarButtons(self.addToolBarButtons())
        }
        self.kernel = kernel
        // onBoot 阶段 StoragePlugin 可能尚未启动（ScenePlugin order=-1000 优先），
        // 先注册无持久化的 SceneProvider 保证下游插件可访问 SceneProviding。
        // 同一个实例全程存活，身份稳定，消费方弱引用不会因后续替换而失效。
        let provider = SceneProvider()
        self.sceneProvider = provider
        try kernel.registerProvider((any SceneProviding).self, provider)
    }

    @MainActor
    public func onReadyAsync(kernel: KernelCoreContainer) async throws {
        // onReady 在所有插件 onBoot 完成后执行，此时 StoragePlugin 已注入 storage。
        // 不再替换实例，只给同一个 SceneProvider 挂上持久化目录并恢复上次场景
        // （对齐 Lumi `DefaultThemeProviding.setStorageDirectory`）。
        if let storage = kernel.resolveProvider((any StorageProviding).self), let sceneProvider {
            let pluginDir = storage.pluginDataDirectory(for: self.id)
            sceneProvider.enablePersistence(pluginDataDirectory: pluginDir)
        }
        kernel.resolveProvider((any SceneProviding).self)?.restoreCurrentScene()
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

    @MainActor
    public func addSettingNavigationItem() -> PluginSettingNavigationItem? {
        // View 贡献可能在插件启动前被请求：保证返回一个稳定、长期存在的
        // ViewModel，而不是每次请求都重新创建。
        let viewModel = settingsViewModel ?? {
            let viewModel = SceneSettingsViewModel(capability: makeSceneCapability(from: kernel?.resolveProvider((any SceneProviding).self)))
            settingsViewModel = viewModel
            return viewModel
        }()
        return PluginSettingNavigationItem(
            id: metadata.id,
            title: metadata.name,
            description: metadata.description,
            iconName: iconName,
            // 设置入口排序不使用 order（-1000 是启动优先级），
            // 使用独立值确保「通用」（order=1）排在最前。
            order: 100,
            destination: AnyView(SceneSettingsView(model: viewModel))
        )
    }

    @MainActor
    public func addToolBarButtons() -> [(id: String, view: AnyView)] {
        guard let kernel else { return [] }
        let viewModel = settingsViewModel ?? {
            let viewModel = SceneSettingsViewModel(capability: makeSceneCapability(from: kernel.resolveProvider((any SceneProviding).self)))
            settingsViewModel = viewModel
            return viewModel
        }()
        return [(id: "scene-switcher", view: AnyView(SceneSwitcher(viewModel: viewModel)))]
    }

    @MainActor
    public func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any PluginContributionProviding).self)?.remove(owner: id)
        teardownSettingsState()
        sceneProvider = nil
        kernel.unregisterProvider((any SceneProviding).self)
    }

    // MARK: - Settings state assembly

    @MainActor
    private func installSettingsState(kernel: KernelCoreContainer) {
        guard settingsViewModel == nil else { return }
        guard let scene = kernel.resolveProvider((any SceneProviding).self) else { return }
        let viewModel = SceneSettingsViewModel(
            capability: makeSceneCapability(from: scene)
        )
        let observer = SceneProvidingObserver(provider: scene, viewModel: viewModel)
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
    private func makeSceneCapability(
        from scene: (any SceneProviding)?
    ) -> (any SceneSettingsCapability)? {
        guard let scene else { return nil }
        return SceneSettingsCapabilityAdapter(scene: scene)
    }
}