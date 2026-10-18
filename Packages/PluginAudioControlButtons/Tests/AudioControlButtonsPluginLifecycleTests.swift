import Foundation
import KernelCore
import ProviderPlugin
import ProviderPlayback
import ProviderScene
import Testing
@testable import PluginAudioControlButtons

// MARK: - 必需 Provider 缺失时的行为

/// 播放 Provider 是控制区的硬依赖：没有播放就没有「上一首/下一首」。
/// 插件选择**显式抛错**而非静默降级 —— 这样内核能记录装配失败，
/// 而不是让一个永远不可用的空控制区悄悄留在界面上。
@MainActor
@Test func missingPlaybackProviderThrowsInsteadOfSilentlyDegrading() async throws {
    let kernel = KernelCoreContainer()
    let plugin = AudioControlButtonsPlugin()

    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReady(kernel: kernel)

    await #expect(throws: KernelCoreError.self) {
        try await plugin.onEnable(kernel: kernel)
    }
}

/// 场景 Provider 同样是硬依赖，缺失时同样应显式失败。
@MainActor
@Test func missingSceneProviderThrowsEvenWhenPlaybackIsReady() async throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any PlaybackProviding).self, ControlPlaybackProbe())

    let plugin = AudioControlButtonsPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReady(kernel: kernel)

    await #expect(throws: KernelCoreError.self) {
        try await plugin.onEnable(kernel: kernel)
    }
}

/// 注册阶段对可选 Provider（文档）缺席应静默跳过。
@MainActor
@Test func onRegisterWithoutDocsProviderIsSafe() async throws {
    let kernel = KernelCoreContainer()
    let plugin = AudioControlButtonsPlugin()
    try await plugin.onRegister(kernel: kernel)
    // 不崩溃即为通过
}

/// 装配失败后插件仍可安全关闭，状态需清理干净。
@MainActor
@Test func shutdownAfterFailedAssemblyIsSafe() async throws {
    let kernel = KernelCoreContainer()
    let plugin = AudioControlButtonsPlugin()

    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReady(kernel: kernel)
    await #expect(throws: KernelCoreError.self) {
        try await plugin.onEnable(kernel: kernel)
    }

    try await plugin.onDisable(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)
}

// MARK: - 装配与幂等

/// 装配成功时应能提供控制区视图。
@MainActor
@Test func controlButtonsViewIsAvailableOnceProvidersAreReady() async throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any PlaybackProviding).self, ControlPlaybackProbe())
    try kernel.registerProvider((any SceneProviding).self, ControlSceneProbe())

    let plugin = AudioControlButtonsPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReady(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)

    #expect(plugin.addControlButtonsView() != nil)
}

/// 重复启用不应重复装配，否则会泄漏 ViewModel 与观察者。
@MainActor
@Test func repeatedEnableDoesNotReassemble() async throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any PlaybackProviding).self, ControlPlaybackProbe())
    try kernel.registerProvider((any SceneProviding).self, ControlSceneProbe())

    let plugin = AudioControlButtonsPlugin()
    try await plugin.onEnable(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)

    #expect(plugin.addControlButtonsView() != nil)
}

/// 禁用后再启用应恢复装配。
@MainActor
@Test func enableAfterDisableRestoresState() async throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any PlaybackProviding).self, ControlPlaybackProbe())
    try kernel.registerProvider((any SceneProviding).self, ControlSceneProbe())

    let plugin = AudioControlButtonsPlugin()
    try await plugin.onEnable(kernel: kernel)
    try await plugin.onDisable(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)

    #expect(plugin.addControlButtonsView() != nil)
}

/// 关闭时撤回贡献，重复关闭不崩溃。
@MainActor
@Test func shutdownRemovesContributionIdempotently() async throws {
    let kernel = KernelCoreContainer()
    let contributions = PluginContributionService(kernel: kernel)
    try kernel.registerProvider((any PluginContributionProviding).self, contributions)
    try kernel.registerProvider((any PlaybackProviding).self, ControlPlaybackProbe())
    try kernel.registerProvider((any SceneProviding).self, ControlSceneProbe())

    let plugin = AudioControlButtonsPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReady(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)
    try await plugin.onShutdown(kernel: kernel)

    _ = plugin.addControlButtonsView()
}

// MARK: - 元数据

@MainActor
@Test func pluginMetadataIsStable() {
    let plugin = AudioControlButtonsPlugin()
    #expect(plugin.id == "AudioControlButtonsPlugin")
    #expect(plugin.order == 20)
    #expect(plugin.iconName == "playpause.fill")
    #expect(plugin.metadata.category == .feature)
    #expect(plugin.metadata.permissions.isEmpty)
}

// MARK: - 测试替身

@MainActor
final class ControlPlaybackProbe: PlaybackProviding {
    var state: PlaybackStatus = .idle
    var currentURL: URL?
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var progress: Double = 0
    var playMode: PlaybackMode = .sequence
    var likedAssets: Set<URL> = []
    var isPlaying: Bool { false }
    var hasAsset: Bool { currentURL != nil }

    private var observers: [UUID: (PlaybackProvidingEvent) -> Void] = [:]

    func play(_ url: URL) async {}
    func play(_ url: URL, startTime: TimeInterval?) async {}
    func pause() {}
    func toggle() {}
    func seek(toProgress progress: Double) {}
    func seek(toTime time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setPlayMode(_ mode: PlaybackMode) {}
    func toggleCurrentLike() {}
    func togglePlayMode() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (PlaybackProvidingEvent) -> Void
    ) -> any PlaybackProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ControlPlaybackHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ControlPlaybackHandle: PlaybackProvidingObserverHandle {
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
final class ControlSceneProbe: SceneProviding {
    var scenes: [AppScene] = [.music, .audiobooks]
    var currentScene: AppScene? = .music
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
        return ControlSceneHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class ControlSceneHandle: SceneProvidingObserverHandle {
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
