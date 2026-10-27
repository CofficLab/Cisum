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
        clearLegacyPersistence()
        defer { clearLegacyPersistence() }

        let kernel = KernelCoreContainer()
        let pluginProvider = PluginContributionService(kernel: kernel)
        let plugin = ScenePlugin()
        try kernel.registerProvider((any PluginProviding).self, pluginProvider)
        try kernel.registerProvider((any PluginContributionProviding).self, pluginProvider)

        try await kernel.startAsync(plugins: [plugin])

        #expect(kernel.resolveProvider((any SceneProviding).self)?.scenes == [.music, .audiobooks])
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

        #expect(service.scenes == AppScene.allCases)
        #expect(service.scenes == [.music, .audiobooks])
    }

    private func makePluginDataDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginSceneTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func clearLegacyPersistence() {
        UserDefaults.standard.removeObject(forKey: "currentSceneName")
        UserDefaults.standard.removeObject(forKey: "currentPluginID")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "currentSceneName")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "currentPluginID")
    }

    @Test
    func persistsAndRestoresCurrentSceneFromDisk() throws {
        let pluginDir = try makePluginDataDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let fileURL = pluginDir.appendingPathComponent("current-scene.json")

        let first = SceneProvider(pluginDataDirectory: pluginDir)
        first.restoreCurrentScene()
        first.setCurrentScene(.audiobooks)

        let second = SceneProvider(pluginDataDirectory: pluginDir)
        second.restoreCurrentScene()

        #expect(second.currentScene == .audiobooks)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func fallsBackToFirstSceneWhenPersistedSceneIsUnknown() throws {
        let pluginDir = try makePluginDataDirectory()
        defer { try? FileManager.default.removeItem(at: pluginDir) }
        let fileURL = pluginDir.appendingPathComponent("current-scene.json")
        let data = Data(#"{"sceneName":"不存在","pluginID":null}"#.utf8)
        try data.write(to: fileURL)

        let service = SceneProvider(pluginDataDirectory: pluginDir)
        service.restoreCurrentScene()

        #expect(service.currentScene == .music)
    }

    @Test
    func notifiesObserversAfterSceneChangesAndSupportsCancellation() throws {
        let pluginDir = try makePluginDataDirectory()
        clearLegacyPersistence()
        defer {
            clearLegacyPersistence()
            try? FileManager.default.removeItem(at: pluginDir)
        }
        let service = SceneProvider(pluginDataDirectory: pluginDir)
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
        clearLegacyPersistence()
        defer {
            clearLegacyPersistence()
            try? FileManager.default.removeItem(at: pluginDir)
        }
        let service = SceneProvider(pluginDataDirectory: pluginDir)
        service.restoreCurrentScene()
        service.setCurrentScene(.audiobooks)

        // 走真实 SceneProvider + Adapter：验证 Adapter 的转发与句柄取消正确。
        let capability = SceneSelectionCapabilityAdapter(scene: service)
        let viewModel = SceneSelectionViewModel(selection: capability)
        let observer = SceneProvidingObserver(selection: capability, viewModel: viewModel)
        defer { observer.cancel() }

        // 监听安装前已经存在的状态不能丢失。
        #expect(viewModel.scenes == AppScene.allCases)
        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func observerForwardsProviderEventsToViewModel() throws {
        let pluginDir = try makePluginDataDirectory()
        clearLegacyPersistence()
        defer {
            clearLegacyPersistence()
            try? FileManager.default.removeItem(at: pluginDir)
        }
        let service = SceneProvider(pluginDataDirectory: pluginDir)
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
        clearLegacyPersistence()
        defer {
            clearLegacyPersistence()
            try? FileManager.default.removeItem(at: pluginDir)
        }
        let service = SceneProvider(pluginDataDirectory: pluginDir)
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
