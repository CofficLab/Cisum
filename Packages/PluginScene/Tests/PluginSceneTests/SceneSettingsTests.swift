import Foundation
import ProviderScene
@testable import PluginScene
import Testing

// MARK: - 场景探针

/// 最小场景 Provider 探针，用于驱动 ViewModel / Capability 适配器。
@MainActor
private final class SceneProbe: ProviderScene.SceneProviding {
    var scenes: [ProviderScene.AppScene] = [.music, .audiobooks]
    var currentScene: ProviderScene.AppScene?
    var setCallCount = 0

    init(current: ProviderScene.AppScene? = nil) {
        self.currentScene = current
    }

    func setCurrentScene(_ scene: ProviderScene.AppScene) {
        setCallCount += 1
        currentScene = scene
    }

    func restoreCurrentScene() {}

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        NoopSceneProvidingObserverHandle()
    }
}

@MainActor
private final class NoopSceneProvidingObserverHandle: SceneProvidingObserverHandle {
    func cancel() {}
}

// MARK: - SceneSettingsViewModel

@MainActor
struct SceneSettingsViewModelTests {
    @Test
    func initLoadsScenesAndCurrentFromCapability() {
        let probe = SceneProbe(current: .audiobooks)
        let viewModel = SceneSettingsViewModel(capability: SceneSettingsCapabilityAdapter(scene: probe))

        #expect(viewModel.scenes == [.music, .audiobooks])
        #expect(viewModel.currentScene == .audiobooks)
        #expect(viewModel.currentSceneIconName == ProviderScene.AppScene.audiobooks.iconName)
    }

    @Test
    func initWithoutCapabilityFallsBackToEmpty() {
        let viewModel = SceneSettingsViewModel(capability: nil)
        #expect(viewModel.scenes.isEmpty)
        #expect(viewModel.currentScene == nil)
        #expect(viewModel.currentSceneIconName == "rectangle.3.group")
    }

    @Test
    func selectDelegatesToCapabilityAndRefreshes() {
        let probe = SceneProbe(current: .music)
        let viewModel = SceneSettingsViewModel(capability: SceneSettingsCapabilityAdapter(scene: probe))

        viewModel.select(.audiobooks)

        #expect(probe.setCallCount == 1)
        #expect(probe.currentScene == .audiobooks)
        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func handleProviderChangedRefreshesState() {
        let probe = SceneProbe(current: .music)
        let viewModel = SceneSettingsViewModel(capability: SceneSettingsCapabilityAdapter(scene: probe))

        // 外部直接改 Provider 状态，再通知 ViewModel 刷新。
        probe.setCurrentScene(.audiobooks)
        viewModel.handleProviderChanged()

        #expect(viewModel.currentScene == .audiobooks)
    }

    @Test
    func selectWithoutCapabilityIsNoOp() {
        let viewModel = SceneSettingsViewModel(capability: nil)
        viewModel.select(.music)
        #expect(viewModel.scenes.isEmpty)
        #expect(viewModel.currentScene == nil)
    }
}

// MARK: - SceneSettingsCapabilityAdapter

@MainActor
struct SceneSettingsCapabilityAdapterTests {
    @Test
    func adapterWeaklyHoldsProviderAndFallsBackWhenReleased() {
        var probe: SceneProbe? = SceneProbe(current: .music)
        let adapter = SceneSettingsCapabilityAdapter(scene: probe!)

        #expect(adapter.scenes == [.music, .audiobooks])
        #expect(adapter.currentScene == .music)

        probe = nil
        #expect(adapter.scenes.isEmpty)
        #expect(adapter.currentScene == nil)

        // 释放后 setCurrentScene 不应崩溃。
        adapter.setCurrentScene(.audiobooks)
    }
}
