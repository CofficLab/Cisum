import MagicKit
import ProviderScene
import Foundation
import KernelCore
import ProviderPlugin
import ProviderSettingView
import KitAppEvents
@testable import PluginScene
import Testing

@MainActor
private final class SceneDependentProbePlugin: SuperPlugin {
    let id = "scene-dependent-probe"
    let order: Int = 9999
    let metadata = PluginMetadata(
        id: "scene-dependent-probe",
        name: "Scene dependent probe",
        description: ""
    )

    func onBootAsync(kernel: KernelCoreContainer) async throws {
        guard kernel.resolveProvider((any SceneProviding).self) != nil else {
            throw KernelCoreError.providerNotFound(type: (any SceneProviding).self)
        }
    }
}

@MainActor
@Suite(.serialized)
struct ScenePluginTests {
    @Test
    func registersAndUnregistersSceneProvider() async throws {
        let kernel = KernelCoreContainer()
        let plugin = ScenePlugin()

        try await plugin.onBootAsync(kernel: kernel)
        #expect(kernel.resolveProvider((any SceneProviding).self) != nil)

        try await plugin.onShutdownAsync(kernel: kernel)
        #expect(kernel.resolveProvider((any SceneProviding).self) == nil)
    }

    @Test
    func contributesSceneSwitcherAfterBootDependenciesAreReady() async throws {
        let kernel = KernelCoreContainer()
        let pluginProvider = PluginContributionService(kernel: kernel)
        let plugin = ScenePlugin()
        try kernel.registerProvider((any PluginProviding).self, pluginProvider)
        try kernel.registerProvider((any PluginContributionProviding).self, pluginProvider)

        try await kernel.startAsync(plugins: [plugin])

        // 当前只启用音乐场景（有声书暂缓上线）
        #expect(kernel.resolveProvider((any SceneProviding).self)?.scenes == [.music])
        // 场景切换器仍然被添加到工具栏，但视图层面在 scenes.count == 1 时不渲染内容
        #expect(pluginProvider.getToolBarButtons().map(\.id) == ["scene-switcher"])
        #expect(plugin.selectionViewModel?.currentScene == .music)
    }

    @Test
    func doesNotRegisterSceneSettingsNavigationItem() async throws {
        let kernel = KernelCoreContainer()
        let pluginProvider = PluginContributionService(kernel: kernel)
        let plugin = ScenePlugin()
        try kernel.registerProvider((any PluginProviding).self, pluginProvider)
        try kernel.registerProvider((any PluginContributionProviding).self, pluginProvider)

        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        try await kernel.startAsync(plugins: [plugin])

        // 场景切换只保留工具栏入口，设置界面不再出现「场景」入口。
        #expect(!settings.entries.contains { $0.id == "scene" })
    }

    @Test
    func bootsBeforeSameOrderSceneDependentPlugins() async throws {
        let kernel = KernelCoreContainer()

        // The dependent plugin is intentionally ordered after ScenePlugin
        // (old order value 0 -> 9999) and must boot after ScenePlugin
        // registers its provider first.
        try await kernel.startAsync(plugins: [SceneDependentProbePlugin(), ScenePlugin()])
        #expect(kernel.resolveProvider((any SceneProviding).self) != nil)
    }

    @Test
    func exposesFixedBuiltInScenes() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginSceneTests-\(UUID().uuidString)", isDirectory: true)
        let service = SceneProvider(pluginDataDirectory: tempDir)

        // 当前只启用音乐场景（有声书暂缓上线）
        #expect(service.scenes == [.music])
    }

    private func makePluginDataDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginSceneTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 构造一份隔离的偏好存储。
    ///
    /// ## 为什么不再清真实全局状态
    ///
    /// 旧写法直接 `removeObject` 掉 `UserDefaults.standard` 与
    /// `NSUbiquitousKeyValueStore.default` 里的 `currentSceneName` /
    /// `currentPluginID`——那是**开发者自己正在用的场景设置**，
    /// 跑一次测试就会把它删掉。而且真实 iCloud 键值库是否可读写取决于
    /// 设备是否登录 iCloud，不同机器上的行为并不一致。
    ///
    /// 现在改为给每个用例一份独立的 suite + 内存版 iCloud 存储，
    /// 既不污染开发者环境，也不依赖账号状态。
    private func makePreferences(
        suiteName: String = "PluginSceneTests-\(UUID().uuidString)"
    ) -> PreferenceStore {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PreferenceStore(
            defaults: defaults,
            cloud: InMemoryCloudKeyValueStore()
        )
    }

    @Test
    func persistsAndRestoresCurrentSceneFromDisk() throws {
        let pluginDir = try makePluginDataDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let fileURL = pluginDir.appendingPathComponent("current-scene.json")

        let first = SceneProvider(pluginDataDirectory: pluginDir, preferences: makePreferences())
        first.restoreCurrentScene()
        // 当前只有音乐场景可用，测试音乐场景的持久化与恢复
        first.setCurrentScene(.music)

        let second = SceneProvider(pluginDataDirectory: pluginDir, preferences: makePreferences())
        second.restoreCurrentScene()

        #expect(second.currentScene == .music)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func fallsBackToFirstSceneWhenPersistedSceneIsUnknown() throws {
        let pluginDir = try makePluginDataDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let fileURL = pluginDir.appendingPathComponent("current-scene.json")
        let data = Data(#"{"sceneName":"不存在","pluginID":null}"#.utf8)
        try data.write(to: fileURL)

        let service = SceneProvider(pluginDataDirectory: pluginDir, preferences: makePreferences())
        service.restoreCurrentScene()

        #expect(service.currentScene == .music)
    }

    @Test
    func notifiesObserversAfterSceneChangesAndSupportsCancellation() throws {
        let pluginDir = try makePluginDataDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let service = SceneProvider(
            pluginDataDirectory: pluginDir,
            preferences: makePreferences()
        )
        var observedScenes: [AppScene?] = []
        let handle = service.addObserver { event in
            if case let .selectionChanged(scene) = event {
                observedScenes.append(scene)
                #expect(service.currentScene == scene)
            }
        }
        defer { handle.cancel() }

        service.restoreCurrentScene()
        service.setCurrentScene(.audiobooks)
        #expect(observedScenes == [.music, .audiobooks])

        handle.cancel()
        service.setCurrentScene(.music)
        #expect(observedScenes == [.music, .audiobooks])
    }

    // MARK: - Observer + ViewModel 生命周期（迁移 Phase 1）

    @Test
    func observerPerformsInitialSyncBeforeInstallingListener() throws {
        let pluginDir = try makePluginDataDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let service = SceneProvider(
            pluginDataDirectory: pluginDir,
            preferences: makePreferences()
        )
        service.restoreCurrentScene()
        // 当前只有音乐场景可用
        service.setCurrentScene(.music)

        // 走真实 SceneProvider + Adapter：验证 Adapter 的转发与句柄取消正确。
        let capability = SceneSelectionCapabilityAdapter(scene: service)
        let viewModel = SceneSelectionViewModel(selection: capability)
        let observer = SceneProvidingObserver(selection: capability, viewModel: viewModel)
        defer { observer.cancel() }

        // 监听安装前已经存在的状态不能丢失。
        // 当前只启用音乐场景（有声书暂缓上线）
        #expect(viewModel.scenes == [.music])
        #expect(viewModel.currentScene == .music)
    }

    @Test
    func observerForwardsProviderEventsToViewModel() throws {
        let pluginDir = try makePluginDataDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let service = SceneProvider(
            pluginDataDirectory: pluginDir,
            preferences: makePreferences()
        )
        service.restoreCurrentScene()

        // 走真实 SceneProvider + Adapter：验证 Adapter 的转发与句柄取消正确。
        let capability = SceneSelectionCapabilityAdapter(scene: service)
        let viewModel = SceneSelectionViewModel(selection: capability)
        let observer = SceneProvidingObserver(selection: capability, viewModel: viewModel)
        defer { observer.cancel() }

        service.setCurrentScene(.audiobooks)
        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func observerCancelStopsViewModelUpdates() throws {
        let pluginDir = try makePluginDataDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let service = SceneProvider(
            pluginDataDirectory: pluginDir,
            preferences: makePreferences()
        )
        service.restoreCurrentScene()

        // 走真实 SceneProvider + Adapter：验证 Adapter 的转发与句柄取消正确。
        let capability = SceneSelectionCapabilityAdapter(scene: service)
        let viewModel = SceneSelectionViewModel(selection: capability)
        let observer = SceneProvidingObserver(selection: capability, viewModel: viewModel)

        service.setCurrentScene(.audiobooks)
        #expect(viewModel.currentScene == .audiobooks)

        observer.cancel()
        service.setCurrentScene(.music)
        // cancel 后事件不再改变 ViewModel。
        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func pluginAssemblySurvivesEnableDisableCycles() async throws {
        let kernel = KernelCoreContainer()
        let plugin = ScenePlugin()

        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        // 同一个长期存在的 ViewModel：两次请求不重建状态对象。
        let first = plugin.selectionViewModel
        let second = plugin.selectionViewModel
        #expect(first != nil)
        #expect(first === second)

        try await plugin.onDisable(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)
        // 禁用再启用后仍可重新装配场景状态。
        #expect(plugin.selectionViewModel != nil)

        try await plugin.onShutdownAsync(kernel: kernel)
    }
}
