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

/// 最小仓库探针：结论由探针给出（数据层负责「扫完了没有」）。
@MainActor
private final class GuideLibraryProbe: GuideLibraryCapability {
    var isRepositoryEmpty = false
    private let registry = GuideObserverRegistry()

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
    func emptyRepositoryActivatesGuide() {
        let probe = GuideLibraryProbe()
        let sceneProbe = GuideSceneProbe()
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        #expect(!slot.isActive)

        probe.isRepositoryEmpty = true
        probe.emit(.changed)
        #expect(slot.isActive)

        observer.cancel()
        #expect(!slot.isActive)
    }

    @Test
    func repositoryBecomesNonEmptyTurnsGuideOff() {
        let probe = GuideLibraryProbe()
        let sceneProbe = GuideSceneProbe()
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        probe.isRepositoryEmpty = true
        probe.emit(.changed)
        #expect(slot.isActive)

        probe.isRepositoryEmpty = false
        probe.emit(.changed)
        #expect(!slot.isActive)

        observer.cancel()
    }

    @Test
    func unknownRepositoryKeepsGuideHidden() {
        // 数据层没给出结论（仓库还没扫过）时，不该点亮引导。
        let probe = GuideLibraryProbe()
        let sceneProbe = GuideSceneProbe()
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        probe.isRepositoryEmpty = false
        probe.emit(.changed)
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

        probe.isRepositoryEmpty = true
        probe.emit(.changed)
        #expect(!slot.isActive)

        observer.cancel()
    }

    @Test
    func sceneChangeReevaluatesActivation() {
        let probe = GuideLibraryProbe()
        let sceneProbe = GuideSceneProbe()
        let slot = makeSlot()
        let observer = RepositoryGuideObserver(slot: slot, library: probe, scene: sceneProbe)

        probe.isRepositoryEmpty = true
        probe.emit(.changed)
        #expect(slot.isActive)

        // 切到有声书场景：引导必须熄灭。
        sceneProbe.currentScene = .audiobooks
        sceneProbe.emit(.selectionChanged(scene: .audiobooks))
        #expect(!slot.isActive)

        observer.cancel()
    }
}
