import Foundation
import KernelCore
import ProviderPlugin
import ProviderPlayback
import Testing
@testable import PluginOpenButton

// MARK: - 插件生命周期与状态装配

/// 注册阶段可能早于 Playback Provider 就绪，缺失时必须静默跳过。
@MainActor
@Test func onRegisterWithoutAnyProviderIsSafe() async throws {
    let kernel = KernelCoreContainer()
    let plugin = OpenButtonPlugin()
    try await plugin.onRegister(kernel: kernel)
    // 不崩溃即为通过
}

/// Playback Provider 缺席时，工具栏不应贡献按钮 ——
/// 没有当前曲目就无从「在 Finder 中显示」。
@MainActor
@Test func toolBarButtonIsAbsentWithoutPlaybackProvider() async throws {
    let kernel = KernelCoreContainer()
    let plugin = OpenButtonPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)

    #if os(macOS)
    #expect(plugin.addToolBarButtons().isEmpty)
    #endif
}

/// Playback Provider 就绪后应装配状态并贡献工具栏按钮。
@MainActor
@Test func toolBarButtonAppearsOncePlaybackProviderIsReady() async throws {
    let kernel = KernelCoreContainer()
    let playback = PluginPlaybackProbe()
    try kernel.registerProvider((any PlaybackProviding).self, playback)

    let plugin = OpenButtonPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)

    #if os(macOS)
    let buttons = plugin.addToolBarButtons()
    #expect(buttons.count == 1)
    #expect(buttons.first?.id == OpenButtonPluginInfo.toolbarItemId)
    #endif
}

/// 重复 onReady 不应重复装配：否则工具栏会出现多个相同按钮，
/// 且 ViewModel/Observer 泄漏。
@MainActor
@Test func repeatedReadyKeepsSingleToolbarButton() async throws {
    let kernel = KernelCoreContainer()
    let playback = PluginPlaybackProbe()
    try kernel.registerProvider((any PlaybackProviding).self, playback)

    let plugin = OpenButtonPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)

    #if os(macOS)
    #expect(plugin.addToolBarButtons().count == 1)
    #endif
}

/// 禁用后应拆除状态，工具栏按钮随之消失。
@MainActor
@Test func onDisableRemovesToolbarButton() async throws {
    let kernel = KernelCoreContainer()
    let playback = PluginPlaybackProbe()
    try kernel.registerProvider((any PlaybackProviding).self, playback)

    let plugin = OpenButtonPlugin()
    try await plugin.onEnable(kernel: kernel)
    #if os(macOS)
    #expect(plugin.addToolBarButtons().count == 1)
    #endif

    try await plugin.onDisable(kernel: kernel)
    #if os(macOS)
    #expect(plugin.addToolBarButtons().isEmpty)
    #endif
}

/// 重新启用后应恢复按钮。
@MainActor
@Test func onEnableRestoresToolbarButtonAfterDisable() async throws {
    let kernel = KernelCoreContainer()
    let playback = PluginPlaybackProbe()
    try kernel.registerProvider((any PlaybackProviding).self, playback)

    let plugin = OpenButtonPlugin()
    try await plugin.onEnable(kernel: kernel)
    try await plugin.onDisable(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)

    #if os(macOS)
    #expect(plugin.addToolBarButtons().count == 1)
    #endif
}

/// 关闭时撤回贡献并拆除状态，重复关闭不应崩溃。
@MainActor
@Test func onShutdownTearsDownStateIdempotently() async throws {
    let kernel = KernelCoreContainer()
    let contributions = PluginContributionService(kernel: kernel)
    try kernel.registerProvider((any PluginContributionProviding).self, contributions)
    let playback = PluginPlaybackProbe()
    try kernel.registerProvider((any PlaybackProviding).self, playback)

    let plugin = OpenButtonPlugin()
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)
    try await plugin.onShutdownAsync(kernel: kernel)
    try await plugin.onShutdownAsync(kernel: kernel)

    #if os(macOS)
    #expect(plugin.addToolBarButtons().isEmpty)
    #endif
}

/// 完整生命周期往返不应崩溃。
@MainActor
@Test func fullLifecycleRoundTripIsSafe() async throws {
    let kernel = KernelCoreContainer()
    let contributions = PluginContributionService(kernel: kernel)
    try kernel.registerProvider((any PluginContributionProviding).self, contributions)
    let playback = PluginPlaybackProbe()
    try kernel.registerProvider((any PlaybackProviding).self, playback)

    let plugin = OpenButtonPlugin()
    try await plugin.onRegister(kernel: kernel)
    try await plugin.onBoot(kernel: kernel)
    try await plugin.onReadyAsync(kernel: kernel)
    try await plugin.onEnable(kernel: kernel)
    try await plugin.onDisable(kernel: kernel)
    try await plugin.onShutdownAsync(kernel: kernel)
}

/// 元数据应稳定，供插件管理器展示。
@MainActor
@Test func pluginMetadataDescribesOpenCurrentEntry() {
    let plugin = OpenButtonPlugin()
    #expect(plugin.id == "OpenButtonPlugin")
    #expect(plugin.order == 9999)
    #expect(plugin.metadata.name == "Open Current")
    #expect(plugin.metadata.category == .feature)
    #expect(plugin.metadata.stage == .stable)
    #expect(plugin.metadata.policy == .alwaysOn)
    #expect(plugin.metadata.permissions.isEmpty)
}

// MARK: - 测试替身

/// 最小播放探针：本文件只关心 Provider 的「存在与否」，不校验转发行为
/// （转发已由 `OpenButtonObserverTests` 覆盖）。
@MainActor
final class PluginPlaybackProbe: PlaybackProviding {
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
        return PluginPlaybackHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class PluginPlaybackHandle: PlaybackProvidingObserverHandle {
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
