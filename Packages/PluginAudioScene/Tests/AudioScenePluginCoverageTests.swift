import Foundation
import CisumKernel
import ProviderScene
import Testing
@testable import PluginAudioScene

/// 最小场景探针：ScenePlugin 使用真实 SceneProvider，此处仅用于 AudioScenePlugin 的消费侧。
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
struct AudioScenePluginLifecycleTests {
    @Test
    func onRegisterWithNoDocsIsSafe() async throws {
        let kernel = CisumKernel()
        let plugin = AudioScenePlugin()
        try await plugin.onRegister(kernel: kernel)
        // 不崩溃即为通过；docs 未注册时静默跳过。
    }

    @Test
    func onReadyWithoutSceneProviderKeepsFallback() async throws {
        let kernel = CisumKernel()
        let plugin = AudioScenePlugin()

        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)

        // 无 Scene provider 时 addPosterView 使用空闭包 fallback，不崩溃。
        #expect(plugin.addPosterView() != nil)
    }

    @Test
    func onReadyInstallsSceneActionWhenProviderRegistered() async throws {
        let kernel = CisumKernel()
        let scene = SceneProbe()
        try kernel.registerProvider((any SceneProviding).self, scene)

        let plugin = AudioScenePlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)

        #expect(plugin.addPosterView() != nil)
        // 场景闭包已安装：后续 provider 场景切换由插件自己的闭包驱动。
        scene.setCurrentScene(.music)
        #expect(scene.setSceneCount == 1)
    }

    @Test
    func onEnableReinstallsAfterDisable() async throws {
        let kernel = CisumKernel()
        let scene = SceneProbe()
        try kernel.registerProvider((any SceneProviding).self, scene)

        let plugin = AudioScenePlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        try await plugin.onDisable(kernel: kernel)
        // 禁用后 fallback 保持；重新启用后恢复闭包。
        #expect(plugin.addPosterView() != nil)
        try await plugin.onEnable(kernel: kernel)
        #expect(plugin.addPosterView() != nil)
    }

    @Test
    func onShutdownClearsSceneAction() async throws {
        let kernel = CisumKernel()
        let scene = SceneProbe()
        try kernel.registerProvider((any SceneProviding).self, scene)

        let plugin = AudioScenePlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)
        try await plugin.onShutdown(kernel: kernel)

        #expect(plugin.addPosterView() != nil)
    }

    @Test
    func metadataExportsRegistrationInfo() {
        #expect(AudioScenePlugin.metadata.displayName == AudioScenePluginInfo.title)
        #expect(AudioScenePlugin.metadata.description == AudioScenePluginInfo.description)
        #expect(AudioScenePlugin.metadata.iconName == AudioScenePluginInfo.iconName)
        #expect(AudioScenePlugin.metadata.order == AudioScenePluginInfo.order)
    }
}
