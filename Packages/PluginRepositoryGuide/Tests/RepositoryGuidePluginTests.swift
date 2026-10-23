import Combine
import Foundation
import KernelCore
import ProviderAudioLibrary
import ProviderControlView
import ProviderDocsView
import SwiftUI
import Testing
@testable import PluginRepositoryGuide

/// 空仓库引导插件的生命周期：装配引导插槽、点亮/熄灭引导、撤回贡献。
@MainActor
struct RepositoryGuidePluginTests {
    /// 音频库替身：引导只关心「是否为空」与仓库事件。
    @MainActor
    private final class AudioLibraryStub: AudioLibraryProviding {
        var isRepositoryEmpty = true
        private var observers: [UUID: (AudioLibraryProvidingEvent) -> Void] = [:]

        var audioDisk: URL? { nil }
        var supportedExtensions: [String] { [] }
        var isAvailable: Bool { true }

        func totalCount() async -> Int { 0 }
        func allURLs(reason: String) async -> [URL] { [] }
        func urls(offset: Int, limit: Int, reason: String) async -> [URL] { [] }
        func contains(_ url: URL) async -> Bool { false }
        func delete(urls: [URL], verbose: Bool) async throws {}
        func sync(urls: [URL], verbose: Bool, isFirst: Bool) async {}
        func sort(url: URL?, reason: String) async {}
        func sortRandom(url: URL?, reason: String, verbose: Bool) async throws {}

        @discardableResult
        func addObserver(
            _ callback: @escaping (AudioLibraryProvidingEvent) -> Void
        ) -> any AudioLibraryProvidingObserverHandle {
            let id = UUID()
            observers[id] = callback
            return StubHandle { [weak self] in
                self?.observers.removeValue(forKey: id)
            }
        }

        func send(_ event: AudioLibraryProvidingEvent) {
            for observer in observers.values { observer(event) }
        }
    }

    @MainActor
    private final class StubHandle: AudioLibraryProvidingObserverHandle {
        private var onCancel: (() -> Void)?

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            onCancel?()
            onCancel = nil
        }
    }

    /// 装配一个「仓库为空」的内核，并返回控制区 Provider 以便检查引导插槽。
    private func makeKernel(
        repositoryEmpty: Bool
    ) throws -> (kernel: KernelCoreContainer, control: DefaultControlViewProvider, library: AudioLibraryStub) {
        let kernel = KernelCoreContainer()
        let control = DefaultControlViewProvider()
        let library = AudioLibraryStub()
        library.isRepositoryEmpty = repositoryEmpty

        try kernel.registerProvider((any ControlViewProviding).self, control)
        try kernel.registerProvider((any AudioLibraryProviding).self, library)
        return (kernel, control, library)
    }

    /// 仓库为空且处于音乐场景时，引导必须被装进播放控制区并点亮。
    @Test
    func readyInstallsAndActivatesGuideSlotWhenRepositoryIsEmpty() async throws {
        let (kernel, control, _) = try makeKernel(repositoryEmpty: true)

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.guideSlot)
        #expect(slot.isActive)
    }

    /// 仓库非空时不得点亮引导——否则用户明明有歌却看到「仓库是空的」。
    @Test
    func guideSlotStaysInactiveWhenRepositoryIsNotEmpty() async throws {
        let (kernel, control, _) = try makeKernel(repositoryEmpty: false)

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.guideSlot)
        #expect(!slot.isActive)
    }

    /// 仓库状态变化后引导必须跟着更新：不再为空就熄灭。
    @Test
    func guideSlotFollowsRepositoryEmptinessChanges() async throws {
        let (kernel, control, library) = try makeKernel(repositoryEmpty: true)

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.guideSlot)
        #expect(slot.isActive)

        library.isRepositoryEmpty = false
        library.send(.synced(totalCount: 3))

        #expect(!slot.isActive)
    }

    /// 关闭时必须熄灭引导并释放能力，不得留下悬空的激活态。
    @Test
    func shutdownDeactivatesGuideSlot() async throws {
        let (kernel, control, _) = try makeKernel(repositoryEmpty: true)

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.guideSlot)
        #expect(slot.isActive)

        try await plugin.onShutdownAsync(kernel: kernel)

        #expect(!slot.isActive)
    }

    /// 注册阶段要把「关于」与「说明书」条目注入文档 Provider。
    @Test
    func registerPublishesAboutAndManualDocsEntries() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        try plugin.onRegister(kernel: kernel)

        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries.first?.id == plugin.id)
        #expect(docs.aboutEntries.first?.name == plugin.metadata.name)
        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(docs.manualEntries.first?.name == plugin.metadata.name)
    }

    /// 缺少播放控制区 Provider 时装配必须安全跳过，不得崩溃。
    @Test
    func readyWithoutControlViewProviderIsSafe() async throws {
        let kernel = KernelCoreContainer()
        let library = AudioLibraryStub()
        try kernel.registerProvider((any AudioLibraryProviding).self, library)

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        #expect(kernel.resolveProvider((any ControlViewProviding).self) == nil)
    }

    /// 重复装配不得换掉引导插槽：控制区在装配时按值捕获插槽，
    /// 换实例会让已渲染的控制区失去引导。
    @Test
    func repeatedReadyKeepsTheSameGuideSlotInstance() async throws {
        let (kernel, control, _) = try makeKernel(repositoryEmpty: true)

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)
        let firstSlot = try #require(control.guideSlot)

        try await plugin.onReadyAsync(kernel: kernel)

        #expect(control.guideSlot === firstSlot)
    }

    /// 文档条目必须能产出**对应**的视图：关于页与说明书页不能是同一个视图。
    @Test
    func docsEntriesProduceTheirOwnViews() async throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = RepositoryGuidePlugin()
        try plugin.onRegister(kernel: kernel)

        let aboutDescription = String(describing: docs.aboutEntries[0].makeView())
        let manualDescription = String(describing: docs.manualEntries[0].makeView())

        #expect(aboutDescription != manualDescription)
        #expect(aboutDescription == String(describing: AnyView(RepositoryGuidePluginAboutView())))
        #expect(manualDescription == String(describing: AnyView(RepositoryGuidePluginManualView())))
    }
}
