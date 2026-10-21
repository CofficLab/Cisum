import Combine
import Foundation
import ProviderAudioLibrary
import ProviderScene
import Testing
@testable import PluginRepositoryGuide

/// 仓库能力适配器：把内核 `AudioLibraryProviding` 收窄为引导用的最小能力。
///
/// 适配器持**惰性解析闭包**而不是 Provider 快照：数据层插件的注册顺序不固定，
/// 快照会让能力在 Provider 稍后就绪时永久失效。这里验证两条主线——
/// Provider 已就绪时立即订阅、Provider 晚到时延迟补订阅。
@MainActor
struct GuideLibraryCapabilityAdapterTests {
    /// 音频库替身：只实现引导关心的「是否为空」与事件广播。
    @MainActor
    private final class AudioLibraryStub: AudioLibraryProviding {
        var isRepositoryEmpty = true
        /// 已建立的观察者数量——用于确定性地判断「适配器是否补上了订阅」。
        private(set) var observerCount = 0
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
            observerCount += 1
            return StubAudioLibraryHandle { [weak self] in
                self?.observers.removeValue(forKey: id)
            }
        }

        func send(_ event: AudioLibraryProvidingEvent) {
            for observer in observers.values { observer(event) }
        }
    }

    @MainActor
    private final class StubAudioLibraryHandle: AudioLibraryProvidingObserverHandle {
        private var onCancel: (() -> Void)?

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            onCancel?()
            onCancel = nil
        }
    }

    /// 装 Provider 的盒子：让解析闭包能在不重建适配器的前提下换掉 Provider，
    /// 同时记录解析次数——用于确定性地等待「重试已用尽」而不是靠猜时长。
    @MainActor
    private final class LibraryBox {
        var library: AudioLibraryStub?
        private(set) var resolveCount = 0

        func resolve() -> AudioLibraryStub? {
            resolveCount += 1
            return library
        }
    }

    /// 等待条件成立。
    ///
    /// 适配器的补订阅重试按固定间隔在主 actor 上排队，投递时刻受负载影响；
    /// 这里轮询直到条件成立或超时，避免用固定 sleep 造成偶发失败。
    private func waitUntil(
        timeout: TimeInterval = 10,
        _ condition: @MainActor () -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    /// 「是否为空」必须每次都重新解析 Provider：数据层稍后就绪时结论要立刻生效。
    @Test
    func repositoryEmptinessIsResolvedOnEveryRead() {
        let box = LibraryBox()
        let adapter = GuideLibraryCapabilityAdapter { box.resolve() }

        // Provider 未就绪时不能断言「空」——那是「还不知道」。
        #expect(!adapter.isRepositoryEmpty)

        let library = AudioLibraryStub()
        library.isRepositoryEmpty = true
        box.library = library
        #expect(adapter.isRepositoryEmpty)

        library.isRepositoryEmpty = false
        #expect(!adapter.isRepositoryEmpty)
    }

    /// Provider 已就绪时立即订阅：任何仓库事件都只意味着「可能变了」。
    @Test
    func everyRepositoryEventIsForwardedAsChanged() {
        let library = AudioLibraryStub()
        let adapter = GuideLibraryCapabilityAdapter { library }

        var changes = 0
        let handle = adapter.addObserver { _ in changes += 1 }

        library.send(.syncing)
        library.send(.synced(totalCount: 0))
        library.send(.updated(totalCount: 3))
        library.send(.deleted(urls: [], totalCount: 0))
        library.send(.repositoryEmpty)
        library.send(.repositoryAvailabilityChanged)
        library.send(.sorting)
        library.send(.sortCompleted)

        #expect(changes == 8)

        handle.cancel()
        library.send(.syncing)
        #expect(changes == 8)
    }

    /// Provider 晚到时必须补订阅，否则用户永远等不到引导。
    @Test
    func pendingObserverIsSubscribedWhenProviderAppearsLater() async throws {
        let box = LibraryBox()
        let adapter = GuideLibraryCapabilityAdapter { box.resolve() }

        var changes = 0
        let handle = adapter.addObserver { _ in changes += 1 }
        #expect(changes == 0)

        let library = AudioLibraryStub()
        box.library = library

        // 等到适配器真的把待订阅回调接到 Provider 上。
        let subscribed = try await waitUntil { library.observerCount > 0 }
        #expect(subscribed)

        library.send(.synced(totalCount: 0))
        #expect(changes == 1)
        handle.cancel()
    }

    /// 取消后不得再补订阅——否则会出现「已取消却仍在收事件」的幽灵订阅。
    @Test
    func cancelledPendingObserverIsNeverSubscribed() async throws {
        let box = LibraryBox()
        let adapter = GuideLibraryCapabilityAdapter { box.resolve() }

        var changes = 0
        let handle = adapter.addObserver { _ in changes += 1 }
        handle.cancel()

        let library = AudioLibraryStub()
        box.library = library
        // 等待重试轮次走过（取消后重试会因「没有待订阅回调」提前结束，
        // 因此这里只需等一小段时间确认没有补订阅发生）。
        try await Task.sleep(nanoseconds: 400_000_000)

        library.send(.synced(totalCount: 0))
        #expect(changes == 0)
        #expect(library.observerCount == 0)
    }

    /// 重试次数用尽后仍然不补订阅：Provider 始终不就绪时，待订阅回调就一直待着。
    ///
    /// 适配器最多重试 10 次；`resolveCount` 记录解析次数——初次解析 1 次 +
    /// 重试 10 次 = 11 次，第 11 次解析之后重试循环才真正走完。
    @Test
    func pendingObserverStaysPendingAfterRetriesAreExhausted() async throws {
        let box = LibraryBox()
        let adapter = GuideLibraryCapabilityAdapter { box.resolve() }

        var changes = 0
        let handle = adapter.addObserver { _ in changes += 1 }

        let exhausted = try await waitUntil { box.resolveCount >= 11 }
        #expect(exhausted)

        // 重试已经用尽：此后 Provider 才出现也不会再补订阅。
        let library = AudioLibraryStub()
        box.library = library
        library.send(.synced(totalCount: 0))

        #expect(changes == 0)
        #expect(library.observerCount == 0)
        handle.cancel()
    }
}

/// 场景能力适配器：把内核 `SceneProviding` 收窄为引导用的最小能力。
@MainActor
struct GuideSceneCapabilityAdapterTests {
    /// 场景替身：记录当前场景并广播切换事件。
    @MainActor
    private final class SceneStub: SceneProviding {
        let objectWillChange = ObservableObjectPublisher()
        var currentScene: AppScene?
        var scenes: [AppScene] { AppScene.allCases }
        private var observers: [UUID: (SceneProvidingEvent) -> Void] = [:]

        func setCurrentScene(_ scene: AppScene) {
            currentScene = scene
        }

        func restoreCurrentScene() {
            currentScene = scenes.first
        }

        @discardableResult
        func addObserver(
            _ callback: @escaping (SceneProvidingEvent) -> Void
        ) -> any SceneProvidingObserverHandle {
            let id = UUID()
            observers[id] = callback
            return StubSceneHandle { [weak self] in
                self?.observers.removeValue(forKey: id)
            }
        }

        func send(_ event: SceneProvidingEvent) {
            for observer in observers.values { observer(event) }
        }
    }

    @MainActor
    private final class StubSceneHandle: SceneProvidingObserverHandle {
        private var onCancel: (() -> Void)?

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            onCancel?()
            onCancel = nil
        }
    }

    /// 当前场景直接透传；Provider 缺席时为 `nil`（尚未恢复）。
    @Test
    func currentSceneIsForwardedFromProvider() {
        let scene = SceneStub()
        let adapter = GuideSceneCapabilityAdapter(scene: scene)

        #expect(adapter.currentScene == nil)

        scene.setCurrentScene(.audiobooks)
        #expect(adapter.currentScene == .audiobooks)
    }

    /// 场景切换必须被转发，并带上切换后的场景。
    @Test
    func sceneSelectionChangesAreForwarded() {
        let scene = SceneStub()
        let adapter = GuideSceneCapabilityAdapter(scene: scene)

        var received: [AppScene?] = []
        let handle = adapter.addObserver { event in
            if case let .selectionChanged(newScene) = event {
                received.append(newScene)
            }
        }

        scene.send(.selectionChanged(scene: .music))
        scene.send(.selectionChanged(scene: nil))

        #expect(received.count == 2)
        #expect(received[0] == .music)
        #expect(received[1] == nil)

        handle.cancel()
        scene.send(.selectionChanged(scene: .audiobooks))
        #expect(received.count == 2)
    }

    /// 没有场景 Provider 时订阅必须安全降级：不得收到事件，也不得崩溃。
    @Test
    func subscriptionWithoutSceneProviderIsSafe() {
        let adapter = GuideSceneCapabilityAdapter(scene: nil)

        #expect(adapter.currentScene == nil)

        let handle = adapter.addObserver { _ in
            Issue.record("A missing scene provider must not deliver events")
        }
        handle.cancel()
        handle.cancel()
    }
}
