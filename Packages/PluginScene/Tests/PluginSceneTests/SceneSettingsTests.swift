import ProviderScene
import Foundation
@testable import PluginScene
import Testing

// MARK: - 场景探针

/// 最小场景选择能力探针，用于驱动 ViewModel。
@MainActor
private final class SceneProbe: SceneSelectionCapability {
    var scenes: [ProviderScene.AppScene] = [.music, .audiobooks]
    var currentScene: ProviderScene.AppScene?
    var setCallCount = 0
    var isAvailable: Bool = true

    init(current: ProviderScene.AppScene? = nil) {
        self.currentScene = current
    }

    func setCurrentScene(_ scene: ProviderScene.AppScene) {
        setCallCount += 1
        currentScene = scene
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneSelectionEvent) -> Void
    ) -> any SceneSelectionObserverHandle {
        NoopSceneProvidingObserverHandle()
    }
}

@MainActor
private final class NoopSceneProvidingObserverHandle: SceneSelectionObserverHandle {
    func cancel() {}
}

/// 最小内核 `SceneProviding` 实现：用于验证 Adapter 的转发行为。
@MainActor
private final class SceneProviderStub: SceneProviding {
    var scenes: [ProviderScene.AppScene] = [.music, .audiobooks]
    var currentScene: ProviderScene.AppScene?
    private var callbacks: [UUID: (SceneProvidingEvent) -> Void] = [:]

    func setCurrentScene(_ scene: ProviderScene.AppScene) { currentScene = scene }
    func restoreCurrentScene() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let id = UUID()
        callbacks[id] = callback
        return StubHandle { [weak self] in self?.callbacks[id] = nil }
    }

    func emit(_ event: SceneProvidingEvent) {
        for callback in Array(callbacks.values) { callback(event) }
    }
}

@MainActor
private final class StubHandle: SceneProvidingObserverHandle {
    private let onCancel: () -> Void
    init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    func cancel() { onCancel() }
}

// MARK: - SceneSelectionCapabilityAdapter

/// 验证 Adapter 对内核 `SceneProviding` 的转发，以及 Provider 缺席时的退化行为。
@MainActor
struct SceneSelectionCapabilityAdapterTests {
    @Test
    func forwardsReadWriteThroughProvider() {
        let provider = SceneProviderStub()
        provider.currentScene = .music
        let capability = SceneSelectionCapabilityAdapter(scene: provider)

        #expect(capability.isAvailable)
        #expect(capability.scenes == [.music, .audiobooks])
        #expect(capability.currentScene == .music)

        // 写入转发：能力 setCurrentScene 应落到 Provider。
        capability.setCurrentScene(.audiobooks)
        #expect(provider.currentScene == .audiobooks)
    }

    @Test
    func degradesGracefullyWhenProviderIsAbsent() {
        let capability = SceneSelectionCapabilityAdapter(scene: nil)

        #expect(!capability.isAvailable)
        #expect(capability.scenes.isEmpty)
        #expect(capability.currentScene == nil)
        // 退化态下写入与订阅不应崩溃。
        capability.setCurrentScene(.music)
        capability.addObserver { _ in }.cancel()
    }

    @Test
    func observerForwardsProviderEventsAndStopsAfterCancel() {
        let provider = SceneProviderStub()
        provider.currentScene = .music
        let capability = SceneSelectionCapabilityAdapter(scene: provider)
        var received = 0
        let handle = capability.addObserver { _ in received += 1 }

        // 内核事件的载荷在能力边界被抹平为无参 `.changed`，但仍应转发一次。
        provider.emit(.selectionChanged(scene: .audiobooks))
        #expect(received == 1)

        handle.cancel()
        handle.cancel()
        provider.emit(.selectionChanged(scene: .music))
        #expect(received == 1)
    }
}

// MARK: - SceneSelectionViewModel

@MainActor
struct SceneSelectionViewModelTests {
    @Test
    func initLoadsScenesAndCurrentFromProvider() {
        let probe = SceneProbe(current: .audiobooks)
        let viewModel = SceneSelectionViewModel(selection: probe)

        #expect(viewModel.scenes == [.music, .audiobooks])
        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func initWithoutProviderFallsBackToEmpty() {
        let viewModel = SceneSelectionViewModel(selection: nil)
        #expect(viewModel.scenes.isEmpty)
        #expect(viewModel.currentScene == nil)
    }

    @Test
    func selectDelegatesToProviderAndRefreshes() {
        let probe = SceneProbe(current: .music)
        let viewModel = SceneSelectionViewModel(selection: probe)

        viewModel.select(.audiobooks)

        #expect(probe.setCallCount == 1)
        #expect(probe.currentScene == .audiobooks)
        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func handleProviderChangedRefreshesState() {
        let probe = SceneProbe(current: .music)
        let viewModel = SceneSelectionViewModel(selection: probe)

        // 外部直接改 Provider 状态，再通知 ViewModel 刷新。
        probe.setCurrentScene(.audiobooks)
        viewModel.handleSelectionChanged()

        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func selectWithoutProviderIsNoOp() {
        let viewModel = SceneSelectionViewModel(selection: nil)
        viewModel.select(.music)
        #expect(viewModel.scenes.isEmpty)
        #expect(viewModel.currentScene == nil)
    }
    @Test
    func viewModelWeaklyHoldsProviderAndFallsBackWhenReleased() {
        var probe: SceneProbe? = SceneProbe(current: .music)
        let viewModel = SceneSelectionViewModel(selection: probe!)

        #expect(viewModel.scenes == [.music, .audiobooks])
        #expect(viewModel.currentScene == .music)

        probe = nil
        #expect(viewModel.scenes.isEmpty)
        #expect(viewModel.currentScene == nil)

        // 释放后 setCurrentScene 不应崩溃。
        viewModel.select(.audiobooks)
    }
}
