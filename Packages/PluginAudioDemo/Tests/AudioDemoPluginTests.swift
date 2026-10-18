import Foundation
import KernelCore
import ProviderPlugin
import ProviderScene
import Testing
@testable import PluginAudioDemo

/// 场景探针：只需暴露 currentScene 供插件的守卫判断。
@MainActor
private final class SceneProbe: SceneProviding {
    var scenes: [AppScene] = [.music, .audiobooks]
    var currentScene: AppScene?
    private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        for observer in observers.values { observer(.selectionChanged(scene: scene)) }
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

@Test func pluginMetadataIsStable() {
    #expect(AudioDemoPluginInfo.iconName == "externaldrive")
    #expect(!AudioDemoPluginInfo.title.isEmpty)
    #expect(!AudioDemoPluginInfo.description.isEmpty)
    #expect(!AudioDemoPluginInfo.tabLabel.isEmpty)
}

@MainActor
@Test func demoAudioFilesAreAvailable() {
    #expect(AudioListDemo.demoAudioFiles.count == 20)
    #expect(AudioItemDemo.iconNames.count == 8)
}

@Test func audioDemoStableIndexHandlesExtremeHashes() {
    #expect(AudioItemDemo.stableIndex(for: Int.min, count: 8) >= 0)
    #expect(AudioItemDemo.stableIndex(for: Int.min, count: 8) < 8)
    #expect(AudioItemDemo.stableIndex(for: -1, count: 8) == 7)
    #expect(AudioItemDemo.stableIndex(for: 9, count: 8) == 1)
    #expect(AudioItemDemo.stableIndex(for: 1, count: 0) == 0)
}

@MainActor
@Test func audioDemoPluginExposesStableIdentityAndMetadata() {
    let plugin = AudioDemoPlugin.shared

    #expect(plugin.id == "AudioDemoPlugin")
    #expect(plugin.order == 1)
    #expect(plugin.iconName == "externaldrive")
    #expect(plugin.metadata.id == "AudioDemoPlugin")
    #expect(plugin.metadata.name == "Audio Repository")
    #expect(plugin.metadata.description == "Audio file database view")
    #expect(plugin.metadata.version == "1.0.0")
    #expect(plugin.metadata.category == .feature)
    #expect(plugin.metadata.stage == .stable)
    #expect(plugin.metadata.policy == .disabled)
    #expect(plugin.metadata.permissions.isEmpty)
}

// MARK: - Tab 视图守卫

/// 未安装 Scene provider 时 sceneBox 为空，必须返回 nil 而不是崩溃。
@MainActor
@Test func addTabViewWithoutSceneProviderReturnsNil() async throws {
    let kernel = KernelCoreContainer()
    let plugin = AudioDemoPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)

    #expect(plugin.addTabView(reason: "tab", demoMode: true) == nil)
}

/// 非 demo 模式一律不展示 —— demo 入口不应出现在正式界面。
@MainActor
@Test func addTabViewReturnsNilOutsideDemoMode() async throws {
    let kernel = KernelCoreContainer()
    let scene = SceneProbe()
    scene.currentScene = .music
    try kernel.registerProvider((any SceneProviding).self, scene)

    let plugin = AudioDemoPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)

    #expect(plugin.addTabView(reason: "tab", demoMode: false) == nil)
}

/// 非音乐场景（有声书）不展示音乐库的 demo 入口。
@MainActor
@Test func addTabViewReturnsNilOutsideMusicScene() async throws {
    let kernel = KernelCoreContainer()
    let scene = SceneProbe()
    scene.currentScene = .audiobooks
    try kernel.registerProvider((any SceneProviding).self, scene)

    let plugin = AudioDemoPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)

    #expect(plugin.addTabView(reason: "tab", demoMode: true) == nil)
}

/// 音乐场景 + demo 模式才返回标签页。
@MainActor
@Test func addTabViewReturnsEntryForMusicDemoMode() async throws {
    let kernel = KernelCoreContainer()
    let scene = SceneProbe()
    scene.currentScene = .music
    try kernel.registerProvider((any SceneProviding).self, scene)

    let plugin = AudioDemoPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)

    let entry = plugin.addTabView(reason: "tab", demoMode: true)
    #expect(entry != nil)
    #expect(entry?.label == AudioDemoPluginInfo.tabLabel)
}

/// 场景切换后守卫应随之改变，避免跨场景残留入口。
@MainActor
@Test func addTabViewFollowsSceneChanges() async throws {
    let kernel = KernelCoreContainer()
    let scene = SceneProbe()
    scene.currentScene = .music
    try kernel.registerProvider((any SceneProviding).self, scene)

    let plugin = AudioDemoPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)
    #expect(plugin.addTabView(reason: "tab", demoMode: true) != nil)

    scene.setCurrentScene(.audiobooks)
    #expect(plugin.addTabView(reason: "tab", demoMode: true) == nil)
}

/// 禁用后 Scene 应被清空，入口随之失效。
@MainActor
@Test func onDisableClearsSceneSoTabDisappears() async throws {
    let kernel = KernelCoreContainer()
    let scene = SceneProbe()
    scene.currentScene = .music
    try kernel.registerProvider((any SceneProviding).self, scene)

    let plugin = AudioDemoPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)
    #expect(plugin.addTabView(reason: "tab", demoMode: true) != nil)

    try await plugin.onDisable(kernel: kernel)
    #expect(plugin.addTabView(reason: "tab", demoMode: true) == nil)
}

/// 重新启用后 Scene 重新安装，入口恢复。
@MainActor
@Test func onEnableReinstallsSceneAfterDisable() async throws {
    let kernel = KernelCoreContainer()
    let scene = SceneProbe()
    scene.currentScene = .music
    try kernel.registerProvider((any SceneProviding).self, scene)

    let plugin = AudioDemoPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onDisable(kernel: kernel)
    #expect(plugin.addTabView(reason: "tab", demoMode: true) == nil)

    try await plugin.onEnable(kernel: kernel)
    #expect(plugin.addTabView(reason: "tab", demoMode: true) != nil)
}

// MARK: - 生命周期

@MainActor
@Test func lifecycleWithoutAnyProviderIsSafe() async throws {
    let kernel = KernelCoreContainer()
    let plugin = AudioDemoPlugin()
    try await plugin.onRegister(kernel: kernel)
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)
    try await plugin.onDisable(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)
    // 不崩溃即为通过
}

@MainActor
@Test func onShutdownRemovesPluginContributions() async throws {
    let kernel = KernelCoreContainer()
    let contributions = PluginContributionService(kernel: kernel)
    try kernel.registerProvider((any PluginContributionProviding).self, contributions)

    let plugin = AudioDemoPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)

    // 关闭后 Scene 清空，tab 不再出现
    #expect(plugin.addTabView(reason: "tab", demoMode: true) == nil)
}
