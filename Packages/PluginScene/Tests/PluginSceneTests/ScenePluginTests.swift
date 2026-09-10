import Foundation
import KernelCore
import ProviderScene
@testable import PluginScene
import Testing

private actor SceneDependentProbePlugin: SuperPlugin {
    static let shared = SceneDependentProbePlugin()

    nonisolated var id: String { "scene-dependent-probe" }

    static var metadata: PluginMetadata {
        PluginMetadata(
            id: "scene-dependent-probe",
            displayName: "Scene dependent probe",
            description: "",
            order: 0
        )
    }

    @MainActor
    func onBoot(kernel: CisumKernel) async throws {
        guard kernel.scene != nil else {
            throw CisumKernelError.serviceNotAvailable(service: "SceneProviding")
        }
    }
}

@MainActor
struct ScenePluginTests {
    @Test
    func registersAndUnregistersSceneProvider() async throws {
        let kernel = CisumKernel()
        let plugin = ScenePlugin()

        try await plugin.onBoot(kernel: kernel)
        #expect(kernel.scene != nil)

        try await plugin.onShutdown(kernel: kernel)
        #expect(kernel.scene == nil)
    }

    @Test
    func contributesSceneSettingsNavigationItem() {
        let item = ScenePlugin().addSettingNavigationItem()

        #expect(item?.id == "scene")
        #expect(item?.title == "Scene")
        #expect(item?.iconName == "rectangle.3.group")
    }

    @Test
    func bootsBeforeSameOrderSceneDependentPlugins() async throws {
        let kernel = CisumKernel()
        let manager = kernel.pluginManager

        // The dependent plugin is intentionally registered first and has the
        // old order value 0. ScenePlugin must still register its provider first.
        manager.initializePlugins([
            SceneDependentProbePlugin(),
            ScenePlugin(),
        ])

        try await manager.onBoot(kernel: kernel)
        #expect(kernel.scene != nil)
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

        let viewModel = SceneSettingsViewModel(
            capability: SceneSettingsCapabilityAdapter(scene: service)
        )
        let observer = SceneProvidingObserver(provider: service, viewModel: viewModel)
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

        let viewModel = SceneSettingsViewModel(
            capability: SceneSettingsCapabilityAdapter(scene: service)
        )
        let observer = SceneProvidingObserver(provider: service, viewModel: viewModel)
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

        let viewModel = SceneSettingsViewModel(
            capability: SceneSettingsCapabilityAdapter(scene: service)
        )
        let observer = SceneProvidingObserver(provider: service, viewModel: viewModel)

        service.setCurrentScene(.audiobooks)
        #expect(viewModel.currentScene == .audiobooks)

        observer.cancel()
        service.setCurrentScene(.music)
        // cancel 后事件不再改变 ViewModel。
        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func pluginAssemblySurvivesEnableDisableCycles() async throws {
        let kernel = CisumKernel()
        let plugin = ScenePlugin()

        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)

        let first = plugin.addSettingNavigationItem()?.destination
        let second = plugin.addSettingNavigationItem()?.destination
        #expect(first != nil)
        // 同一个长期存在的 ViewModel：两次请求不重建状态对象。
        #expect(second != nil)

        try await plugin.onDisable(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)
        // 禁用再启用后仍可注入设置导航项。
        #expect(plugin.addSettingNavigationItem() != nil)

        try await plugin.onShutdown(kernel: kernel)
    }
}
