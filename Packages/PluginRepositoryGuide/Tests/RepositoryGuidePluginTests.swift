import Combine
import Foundation
import KernelCore
import ProviderAudioLibrary
import ProviderBook
import ProviderControlView
import ProviderDocsView
import ProviderScene
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

    /// 书籍库替身：引导只关心总条目数与仓库变化事件。
    @MainActor
    private final class BookLibraryStub: BookDatabaseProviding {
        var count: Int
        var bookDisk: URL? { nil }
        var isAvailable: Bool { true }
        var databaseRoot: URL { URL(fileURLWithPath: "/tmp/cisum-book-guide-stub") }

        private var observers: [UUID: @MainActor @Sendable (BookProvidingEvent) -> Void] = [:]
        private var handles: [UUID: BookStubHandle] = [:]

        init(count: Int) {
            self.count = count
        }

        func totalCount() async -> Int { count }
        func books(reason: String) async -> [BookDTO] { [] }
        func syncImportedItems(_ items: [URL]) async throws {}
        func coverData(for bookURL: URL) async -> Data? { nil }
        func playbackState(for bookURL: URL) async -> BookPlaybackStateDTO? { nil }
        func savePlaybackState(
            for bookURL: URL,
            currentURL: URL?,
            time: TimeInterval?
        ) async throws {}
        func currentBookURL() -> URL? { nil }
        func currentBookTime() -> TimeInterval? { nil }
        func storeCurrentBookURL(_ url: URL?) {}
        func storeCurrentBookTime(_ time: TimeInterval) {}

        @discardableResult
        func addObserver(
            _ callback: @escaping @MainActor @Sendable (BookProvidingEvent) -> Void
        ) -> any BookProvidingObserverHandle {
            let id = UUID()
            observers[id] = callback
            let handle = BookStubHandle { [weak self] in
                self?.observers.removeValue(forKey: id)
                self?.handles.removeValue(forKey: id)
            }
            handles[id] = handle
            return handle
        }

        func send(_ event: BookProvidingEvent) {
            for observer in observers.values { observer(event) }
        }
    }

    @MainActor
    private final class BookStubHandle: BookProvidingObserverHandle {
        private var onCancel: (() -> Void)?

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            onCancel?()
            onCancel = nil
        }
    }

    /// 场景替身：用于把当前场景钉在有声书。
    @MainActor
    private final class SceneStub: ObservableObject, SceneProviding {
        @Published var currentScene: AppScene?

        init(scene: AppScene?) {
            currentScene = scene
        }

        var scenes: [AppScene] { AppScene.allCases }
        func setCurrentScene(_ scene: AppScene) { currentScene = scene }
        func restoreCurrentScene() {}
    }

    /// 等待异步结论落地（书籍库是异步 `totalCount()`）。
    private func waitForGuideActivation(
        _ slot: ControlGuideSlot,
        expected: Bool
    ) async -> Bool {
        for _ in 0 ..< 20 {
            if slot.isActive == expected { return true }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return slot.isActive == expected
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

    /// 装配一个当前处于有声书场景的内核。
    private func makeAudiobookKernel(
        musicRepositoryEmpty: Bool,
        bookCount: Int
    ) throws -> (
        kernel: KernelCoreContainer,
        control: DefaultControlViewProvider,
        books: BookLibraryStub,
        scene: SceneStub
    ) {
        let kernel = KernelCoreContainer()
        let control = DefaultControlViewProvider()
        let library = AudioLibraryStub()
        library.isRepositoryEmpty = musicRepositoryEmpty
        let books = BookLibraryStub(count: bookCount)
        let scene = SceneStub(scene: .audiobooks)

        try kernel.registerProvider((any ControlViewProviding).self, control)
        try kernel.registerProvider((any AudioLibraryProviding).self, library)
        try kernel.registerProvider((any BookDatabaseProviding).self, books)
        try kernel.registerProvider((any SceneProviding).self, scene)
        return (kernel, control, books, scene)
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

    /// 有声书场景、书籍仓库为空：头部引导必须和音乐场景一样点亮。
    @Test
    func audiobookSceneWithEmptyBookLibraryActivatesGuide() async throws {
        let (kernel, control, _, _) = try makeAudiobookKernel(
            musicRepositoryEmpty: false,
            bookCount: 0
        )

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.guideSlot)
        #expect(await waitForGuideActivation(slot, expected: true))
    }

    /// 有声书场景、书籍仓库非空：不得点亮头部引导。
    @Test
    func audiobookSceneWithNonEmptyBookLibraryKeepsGuideInactive() async throws {
        let (kernel, control, _, _) = try makeAudiobookKernel(
            musicRepositoryEmpty: true,
            bookCount: 3
        )

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.guideSlot)
        #expect(await waitForGuideActivation(slot, expected: false))
    }

    /// 有声书场景下书籍被删空：事件里的总数应直接点亮引导。
    @Test
    func bookLibraryGoingEmptyActivatesGuide() async throws {
        let (kernel, control, books, _) = try makeAudiobookKernel(
            musicRepositoryEmpty: false,
            bookCount: 2
        )

        let plugin = RepositoryGuidePlugin()
        try await plugin.onBootAsync(kernel: kernel)
        try await plugin.onReadyAsync(kernel: kernel)

        let slot = try #require(control.guideSlot)
        #expect(await waitForGuideActivation(slot, expected: false))

        books.count = 0
        books.send(.libraryChanged(totalCount: 0))

        #expect(await waitForGuideActivation(slot, expected: true))
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
