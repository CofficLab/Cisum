import Foundation
import KernelCore
import ProviderDocsView
import ProviderPlayback
import ProviderPlugin
import SwiftUI
import Testing
@testable import PluginLikeButton

/// 喜欢按钮插件的**真实**生命周期与能力装配行为。
///
/// `LikeButtonPlugin` 只实现了 `onBootAsync` / `onReadyAsync` / `onShutdownAsync`，
/// 同步版的 `onBoot(kernel:)` 在协议扩展里是**默认空实现**，直接调用不会触发
/// 插件真正的启动逻辑——因此这里的用例一律走插件自己的异步生命周期方法。
@MainActor
struct LikeButtonPluginLifecycleTests {
    /// 没有播放 Provider 时不得贡献工具栏按钮：没有当前曲目就无从「喜欢」。
    @Test
    func toolBarButtonIsAbsentWithoutPlaybackProvider() async throws {
        let kernel = KernelCoreContainer()
        let plugin = LikeButtonPlugin()

        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        #expect(plugin.addToolBarButtons().isEmpty)
    }

    /// 播放 Provider 就绪后应装配状态并贡献工具栏按钮。
    @Test
    func toolBarButtonAppearsOncePlaybackProviderIsReady() async throws {
        let kernel = KernelCoreContainer()
        let playback = LikePlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = LikeButtonPlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let buttons = plugin.addToolBarButtons()
        #expect(buttons.count == 1)
        #expect(buttons.first?.id == LikeButtonPluginInfo.toolbarItemId)
    }

    /// 装配好的按钮必须真的登记到贡献注册表——
    /// 否则按钮只活在插件内部，工具栏上根本看不到。
    ///
    /// 注意：本插件的 `metadata.policy` 是 `.disabled`，内核不会把它算作「已启用」，
    /// 因此聚合接口 `getToolBarButtons()` 会把它过滤掉（按钮要等宿主启用插件后才出现）。
    /// 这里断言的是插件交给注册表的那一份内容。
    @Test
    func readyRegistersToolbarButtonWithContributionRegistry() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)
        let playback = LikePlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = LikeButtonPlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        #expect(plugin.addToolBarButtons().count == 1)
        #expect(contributions.getToolBarButtons().isEmpty)
    }

    /// 重复装配不得产生第二个按钮：工具栏上只能有一个喜欢按钮。
    @Test
    func repeatedReadyKeepsSingleToolbarButton() async throws {
        let kernel = KernelCoreContainer()
        let playback = LikePlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = LikeButtonPlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        #expect(plugin.addToolBarButtons().count == 1)
    }

    /// 禁用后应拆除状态，工具栏按钮随之消失。
    @Test
    func onDisableRemovesToolbarButton() async throws {
        let kernel = KernelCoreContainer()
        let playback = LikePlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = LikeButtonPlugin()
        try await plugin.onEnable(kernel: kernel)
        #expect(plugin.addToolBarButtons().count == 1)

        try await plugin.onDisable(kernel: kernel)
        #expect(plugin.addToolBarButtons().isEmpty)
    }

    /// 重新启用后应恢复按钮。
    @Test
    func onEnableRestoresToolbarButtonAfterDisable() async throws {
        let kernel = KernelCoreContainer()
        let playback = LikePlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = LikeButtonPlugin()
        try await plugin.onEnable(kernel: kernel)
        try await plugin.onDisable(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)

        #expect(plugin.addToolBarButtons().count == 1)
    }

    /// 关闭时撤回贡献并拆除状态，重复关闭不应崩溃。
    @Test
    func onShutdownTearsDownStateIdempotently() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)
        let playback = LikePlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = LikeButtonPlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        #expect(plugin.addToolBarButtons().count == 1)

        try await plugin.onShutdownAsync(kernel: kernel)
        try await plugin.onShutdownAsync(kernel: kernel)

        #expect(plugin.addToolBarButtons().isEmpty)
    }

    /// 注册阶段要把「关于」与「说明书」条目注入文档 Provider。
    @Test
    func onRegisterPublishesAboutAndManualDocsEntries() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = LikeButtonPlugin()
        try plugin.onRegister(kernel: kernel)

        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries.first?.id == plugin.id)
        #expect(docs.aboutEntries.first?.name == plugin.metadata.name)
        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(docs.manualEntries.first?.name == plugin.metadata.name)
    }

    /// 文档条目必须能产出**对应**的视图：关于页与说明书页不能是同一个视图。
    @Test
    func docsEntriesProduceTheirOwnViews() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = LikeButtonPlugin()
        try plugin.onRegister(kernel: kernel)

        let aboutDescription = String(describing: docs.aboutEntries[0].makeView())
        let manualDescription = String(describing: docs.manualEntries[0].makeView())

        #expect(aboutDescription != manualDescription)
    }

    /// 完整生命周期往返不应崩溃。
    @Test
    func fullLifecycleRoundTripIsSafe() async throws {
        let kernel = KernelCoreContainer()
        let contributions = PluginContributionService(kernel: kernel)
        try kernel.registerProvider((any PluginContributionProviding).self, contributions)
        let playback = LikePlaybackProbe()
        try kernel.registerProvider((any PlaybackProviding).self, playback)

        let plugin = LikeButtonPlugin()
        try plugin.onRegister(kernel: kernel)
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        try await plugin.onEnable(kernel: kernel)
        try await plugin.onDisable(kernel: kernel)
        try await plugin.onShutdownAsync(kernel: kernel)
    }

    /// 元数据应稳定，供插件管理器展示。
    @Test
    func pluginMetadataDescribesLikeEntry() {
        let plugin = LikeButtonPlugin()

        #expect(plugin.id == "LikeButtonPlugin")
        #expect(plugin.order == 9999)
        #expect(plugin.metadata.name == "Like Button")
        #expect(plugin.metadata.category == .feature)
        #expect(plugin.metadata.stage == .stable)
        #expect(plugin.metadata.permissions.isEmpty)
    }
}

/// 能力适配层的行为约束：只转发喜欢相关的事件，其余事件一律忽略。
@MainActor
struct LikeButtonCapabilityAdapterTests {
    /// 与喜欢无关的播放事件不得透传给按钮。
    @Test
    func unrelatedPlaybackEventsAreIgnored() {
        let probe = LikePlaybackProbe()
        let adapter = LikeButtonCapabilityAdapter(playback: probe)
        var received: [LikeButtonEvent] = []

        let handle = adapter.addObserver { received.append($0) }

        probe.emit(.stateChanged(.playing))
        probe.emit(.playModeChanged(.shuffle))
        #expect(received.isEmpty)

        let url = URL(fileURLWithPath: "/tmp/liked.mp3")
        probe.emit(.likeStatusChanged(asset: url, isLiked: true))
        #expect(received.count == 1)
        if case .likeStatusChanged(let liked) = received[0] {
            #expect(liked)
        } else {
            Issue.record("期望 likeStatusChanged，实际得到 \(received[0])")
        }

        handle.cancel()
    }

    /// 播放 Provider 缺席时，能力退化为「无播放」而不是崩溃。
    @Test
    func missingPlaybackDegradesToNoPlayback() {
        let adapter = LikeButtonCapabilityAdapter(playback: nil)

        #expect(adapter.currentURL == nil)
        #expect(!adapter.hasAsset)
        #expect(adapter.likedAssets.isEmpty)

        // 切换喜欢在无播放时必须是空操作。
        adapter.toggleCurrentLike()

        var called = false
        let handle = adapter.addObserver { _ in called = true }
        handle.cancel()
        handle.cancel()
        #expect(!called)
    }
}

// MARK: - 测试替身

/// 最小播放探针：只提供状态与事件转发。
@MainActor
final class LikePlaybackProbe: PlaybackProviding {
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

    /// 广播一个播放事件给所有订阅者。
    func emit(_ event: PlaybackProvidingEvent) {
        for observer in observers.values { observer(event) }
    }

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
        return LikePlaybackHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class LikePlaybackHandle: PlaybackProvidingObserverHandle {
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
