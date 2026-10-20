import Foundation
import ProviderControlView
import ProviderScene
import SwiftUI
import Testing
@testable import PluginRepositoryGuide

/// 观察者登记表：探针用它持有回调。
///
/// 单独成类是为了让订阅句柄的取消闭包**不捕获探针自身**（只捕获登记表），
/// 避免弱引用闭包在严格并发检查下的可见性问题。
@MainActor
private final class GuideObserverRegistry {
    private var callbacks: [UUID: (GuideLibraryEvent) -> Void] = [:]

    func insert(_ callback: @escaping (GuideLibraryEvent) -> Void) -> UUID {
        let id = UUID()
        callbacks[id] = callback
        return id
    }

    func remove(_ id: UUID) {
        callbacks.removeValue(forKey: id)
    }

    func emit(_ event: GuideLibraryEvent) {
        for callback in callbacks.values { callback(event) }
    }
}

/// 最小仓库探针：可广播仓库事件并返回计数。
@MainActor
private final class GuideLibraryProbe: GuideLibraryCapability {
    var audioDisk: URL?
    var supportedExtensions: [String] = ["mp3"]
    var isAvailable: Bool = true
    var totalCountValue = 0
    private let registry = GuideObserverRegistry()

    func totalCount() async -> Int { totalCountValue }

    func sync(urls: [URL]) async {}

    func emit(_ event: GuideLibraryEvent) {
        registry.emit(event)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (GuideLibraryEvent) -> Void
    ) -> any GuideLibraryObserverHandle {
        let id = registry.insert(callback)
        return GuideLibraryHandle { [registry] in
            registry.remove(id)
        }
    }
}

/// 最小场景探针。
@MainActor
private final class GuideSceneProbe: GuideSceneCapability {
    var currentScene: AppScene?
    private var callbacks: [UUID: (GuideSceneEvent) -> Void] = [:]

    func emit(_ event: GuideSceneEvent) {
        for callback in callbacks.values { callback(event) }
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (GuideSceneEvent) -> Void
    ) -> any GuideSceneObserverHandle {
        let id = UUID()
        callbacks[id] = callback
        return GuideSceneHandle { [weak self] in
            self?.callbacks.removeValue(forKey: id)
        }
    }
}

@MainActor
private final class GuideLibraryHandle: GuideLibraryObserverHandle {
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
private final class GuideSceneHandle: GuideSceneObserverHandle {
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
struct RepositoryGuideObserverTests {
    private func makeSlot() -> ControlGuideSlot {
        ControlGuideSlot(
            guideView: AnyView(Color.red)
        )
    }

    @Test
    func repositoryEmptyEventActivatesGuide() {
        let probe = GuideLibraryProbe()
        let sceneProbe = GuideSceneProbe()
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        #expect(!slot.isActive)
        probe.emit(.repositoryEmpty)
        #expect(slot.isActive)

        observer.cancel()
        #expect(!slot.isActive)
    }

    @Test
    func repositoryBecomesNonEmptyTurnsGuideOff() async throws {
        let probe = GuideLibraryProbe()
        let sceneProbe = GuideSceneProbe()
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        probe.emit(.repositoryEmpty)
        #expect(slot.isActive)

        probe.totalCountValue = 1
        probe.emit(.changed)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(!slot.isActive)

        observer.cancel()
    }

    @Test
    func zeroCountAfterSyncRelightsGuide() async throws {
        let probe = GuideLibraryProbe()
        let sceneProbe = GuideSceneProbe()
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        probe.totalCountValue = 1
        probe.emit(.changed)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(!slot.isActive)

        probe.totalCountValue = 0
        probe.emit(.changed)
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(slot.isActive)

        observer.cancel()
    }

    @Test
    func unavailableLibraryKeepsGuideStateUnchanged() async throws {
        let probe = GuideLibraryProbe()
        probe.isAvailable = false
        let sceneProbe = GuideSceneProbe()
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        probe.totalCountValue = 0
        probe.emit(.changed)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Provider 未就绪时的 0 计数不代表「仓库为空」，不能误点亮引导。
        #expect(!slot.isActive)

        observer.cancel()
    }

    @Test
    func nonMusicSceneKeepsGuideHidden() {
        let probe = GuideLibraryProbe()
        let sceneProbe = GuideSceneProbe()
        sceneProbe.currentScene = .audiobooks
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        probe.emit(.repositoryEmpty)
        #expect(!slot.isActive)

        observer.cancel()
    }
}
