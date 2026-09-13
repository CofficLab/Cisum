import Foundation
import KernelCore
import ProviderScene
import Testing
@testable import PluginBookScene

/// 最小场景探针：BookScenePlugin 的消费侧测试用。
@MainActor
private final class SceneProbe: SceneProviding {
    var scenes: [AppScene] = [.music, .audiobooks]
    var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    var setSceneCount = 0

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        setSceneCount += 1
        let event = SceneProvidingEvent.selectionChanged(scene: scene)
        for observer in observers.values { observer(event) }
    }

    func restoreCurrentScene() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ProbeSceneHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ProbeSceneHandle: SceneProvidingObserverHandle {
    private let onCancel: () -> Void
    private var cancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        onCancel()
    }
}

@MainActor
struct BookScenePluginLifecycleTests {
    @Test
    func onRegisterWithNoDocsIsSafe() async throws {
        let kernel = CisumKernel()
        let plugin = BookScenePlugin()
        try await plugin.onRegister(kernel: kernel)
        // docs 未注册时静默跳过，不崩溃。
    }

    @Test
    func onReadyWithoutSceneProviderKeepsFallback() async throws {
        let kernel = CisumKernel()
        let plugin = BookScenePlugin()

        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)

        #expect(plugin.addPosterView() != nil)
    }

    @Test
    func onReadyInstallsSceneActionWhenProviderRegistered() async throws {
        let kernel = CisumKernel()
        let scene = SceneProbe()
        try kernel.registerProvider((any SceneProviding).self, scene)

        let plugin = BookScenePlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)

        #expect(plugin.addPosterView() != nil)
        scene.setCurrentScene(.audiobooks)
        #expect(scene.setSceneCount == 1)
    }

    @Test
    func onEnableReinstallsAfterDisable() async throws {
        let kernel = CisumKernel()
        let scene = SceneProbe()
        try kernel.registerProvider((any SceneProviding).self, scene)

        let plugin = BookScenePlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        try await plugin.onDisable(kernel: kernel)
        #expect(plugin.addPosterView() != nil)
        try await plugin.onEnable(kernel: kernel)
        #expect(plugin.addPosterView() != nil)
    }

    @Test
    func onShutdownClearsSceneAction() async throws {
        let kernel = CisumKernel()
        let scene = SceneProbe()
        try kernel.registerProvider((any SceneProviding).self, scene)

        let plugin = BookScenePlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        try await plugin.onShutdown(kernel: kernel)

        #expect(plugin.addPosterView() != nil)
    }

    @Test
    func metadataExportsRegistrationInfo() {
        #expect(BookScenePlugin.metadata.displayName == BookScenePluginInfo.title)
        #expect(BookScenePlugin.metadata.description == BookScenePluginInfo.description)
        #expect(BookScenePlugin.metadata.iconName == BookScenePluginInfo.iconName)
        #expect(BookScenePlugin.metadata.order == BookScenePluginInfo.order)
    }
}
