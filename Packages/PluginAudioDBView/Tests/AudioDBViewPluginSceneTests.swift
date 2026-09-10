import KernelCore
import ProviderScene
import Testing
@testable import PluginAudioDBView

/// 回归测试：内容区「音乐库」Tab 的 `SceneProviding` 解析时机。
///
/// `ScenePlugin`（order -1000）会在自己的 `onReady` 里用带持久化的**新实例**
/// 替换 `onBoot` 阶段注册的临时实例（见 `ScenePlugin.onReady`）。插件若在
/// `onBoot` 捕获 scene，`SceneBox.scene`（weak）会随旧实例失效，
/// `addTabView` 的音乐场景守卫恒为 false，音乐库内容区退化成
/// 「当前场景暂无可用内容」。修复后必须在 `onReady` 解析 scene。
@MainActor
struct AudioDBViewPluginSceneTests {
    @Test
    func contributesMusicTabWithSceneProviderResolvedAtReady() async throws {
        let kernel = CisumKernel()
        // onBoot 阶段存在的临时 Provider；它不会被替换后再更新场景。
        try kernel.registerSceneService(StubSceneProvider(currentScene: .audiobooks))

        let plugin = AudioDBViewPlugin()
        try await plugin.onBoot(kernel: kernel)

        // 模拟 ScenePlugin.onReady：不再替换实例，只给同一个 SceneProvider 挂上
        // 持久化目录并恢复上次场景。这里用 Stub 直接 setCurrentScene(.music)。
        let liveProvider = kernel.resolveProvider(SceneProviding.self) as? StubSceneProvider
        #expect(liveProvider != nil)
        liveProvider?.setCurrentScene(.music)

        try await plugin.onReady(kernel: kernel)

        // 读到的是同一个实例 → 音乐场景贡献 Tab（旧实现读到的是被释放的临时
        // Provider 弱引用 nil，此断言会失败）。
        #expect(plugin.addTabView(reason: "AppTabView") != nil)

        // 场景切走后不再贡献，切回后恢复 —— 守卫跟随当前激活 Provider。
        liveProvider?.setCurrentScene(.audiobooks)
        #expect(plugin.addTabView(reason: "AppTabView") == nil)

        liveProvider?.setCurrentScene(.music)
        #expect(plugin.addTabView(reason: "AppTabView") != nil)
    }

    @Test
    func duplicateSceneRegistrationThrowsUntilUnregistered() async throws {
        let kernel = CisumKernel()
        try kernel.registerSceneService(StubSceneProvider(currentScene: .music))

        // 重复注册同一个 key 必须抛 providerAlreadyRegistered。
        #expect(throws: CisumKernelError.self) {
            try kernel.registerSceneService(StubSceneProvider(currentScene: .audiobooks))
        }

        // 显式 unregister 后允许再次注册（Lumi 风格的合法替换路径）。
        kernel.unregisterProvider(SceneProviding.self)
        try kernel.registerSceneService(StubSceneProvider(currentScene: .audiobooks))
        #expect(kernel.scene?.currentScene == .audiobooks)
    }
}

/// 轻量 `SceneProviding` 替身：仅维护当前场景并同步派发观察者事件。
@MainActor
private final class StubSceneProvider: SceneProviding {
    let scenes: [AppScene] = AppScene.allCases
    private(set) var currentScene: AppScene?

    private var observers: [(SceneProvidingEvent) -> Void] = []

    init(currentScene: AppScene?) {
        self.currentScene = currentScene
    }

    func setCurrentScene(_ scene: AppScene) {
        currentScene = scene
        for observer in observers {
            observer(.selectionChanged(scene: scene))
        }
    }

    func restoreCurrentScene() {
        currentScene = scenes.first
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        observers.append(callback)
        return NoopSceneProvidingObserverHandle()
    }
}
