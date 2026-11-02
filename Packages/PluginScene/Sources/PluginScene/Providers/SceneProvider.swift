import ProviderScene
import Combine
import Foundation
import MagicKit

/// `SceneProviding` 的磁盘持久化实现。
///
/// 场景为 Provider 内置的固定枚举（`AppScene.allCases`），不再从插件
/// `addSceneItem()` 贡献中收集，因此本实现不再依赖 `BuiltinPluginManager`。
///
/// ## 存储目录（对齐 GitOK）
/// 由调用方通过 `StorageProviding.pluginDataDirectory(for: pluginID)` 解析，
/// 目录名即插件 ID，文件落盘到 `<pluginDataDirectory>/current-scene.json`。
@MainActor
public final class SceneProvider: ObservableObject, SceneProviding {
    private struct PersistedScene: Codable {
        let sceneName: String
        let pluginID: String?
    }

    private static let legacySceneKey = "currentSceneName"
    private static let legacyPluginIDKey = "currentPluginID"
    private static let persistenceFileName = "current-scene.json"

    private var persistenceURL: URL?
    private var observers: [WeakObserver] = []

    /// 旧版场景键的持久化存储。
    ///
    /// 过去这里直接写 `UserDefaults.standard` 与 `NSUbiquitousKeyValueStore.default`
    /// ——进程级全局状态，单元测试无法替换，且测试会清掉**开发者真实的场景
    /// 设置**（`currentSceneName` / `currentPluginID`）。改为注入后，
    /// 生产行为不变，测试可用独立 suite 精确控制。
    private let preferences: PreferenceStore

    @Published public private(set) var currentScene: AppScene?

    /// 无持久化目录的临时实例（`onBoot` 阶段使用，此时 StoragePlugin 可能尚未就绪）。
    /// 后续由 `ScenePlugin.onReady` 调用 `enablePersistence(pluginDataDirectory:)`
    /// 挂上目录并恢复上次场景 —— 同一个实例全程存活，身份稳定，
    /// 避免替换实例导致消费方持有的弱引用变成空号。
    /// - Parameter preferences: 偏好存储。生产传 ``PreferenceStore/shared``。
    public init(preferences: PreferenceStore = .shared) {
        self.preferences = preferences
        self.persistenceURL = nil
        self.currentScene = nil
    }

    /// - Parameter pluginDataDirectory: 插件专属数据目录
    ///   （由 `StorageProviding.pluginDataDirectory(for: pluginID)` 解析得到）。
    ///   传 `nil` 时禁用磁盘持久化（仅内存态，用于 onBoot 阶段 Storage 尚未就绪时）。
    ///
    /// 主要供测试场景直接构造已挂载目录的实例；生产代码推荐使用 `init()` +
    /// `enablePersistence(pluginDataDirectory:)` 的两阶段初始化。
    /// - Parameters:
    ///   - pluginDataDirectory: 插件专属数据目录。传 `nil` 时禁用磁盘持久化。
    ///   - preferences: 偏好存储。生产传 ``PreferenceStore/shared``。
    public init(pluginDataDirectory: URL?, preferences: PreferenceStore = .shared) {
        self.preferences = preferences
        self.persistenceURL = pluginDataDirectory?
            .appendingPathComponent(Self.persistenceFileName, isDirectory: false)
        self.currentScene = nil
    }

    /// 在已有实例上挂载持久化目录，并立即触发 `restoreCurrentScene()`。
    ///
    /// 对齐 Lumi `DefaultThemeProviding.setStorageDirectory(_:)`：实例身份保持稳定，
    /// 只把"何时知道目录"这件事延迟到 Storage 就绪之后。
    public func enablePersistence(pluginDataDirectory: URL) {
        persistenceURL = pluginDataDirectory
            .appendingPathComponent(Self.persistenceFileName, isDirectory: false)
        restoreCurrentScene()
    }

    public var scenes: [AppScene] {
        // 临时只启用音乐场景，有声书功能暂缓上线。
        // 恢复有声书功能时改回 `AppScene.allCases`。
        [.music]
    }

    public func setCurrentScene(_ scene: AppScene) {
        if currentScene == scene {
            if loadPersistedSceneName() == scene.rawValue { return }
            try? persistScene(scene)
            return
        }

        try? persistScene(scene)
        currentScene = scene
        notify(.selectionChanged(scene: scene))
    }

    /// 从磁盘恢复当前场景；无记录或记录失效时回落到首个场景。
    public func restoreCurrentScene() {
        let scenes = self.scenes
        guard let first = scenes.first else {
            updateCurrentScene(nil)
            return
        }

        // UI 测试专用：忽略磁盘上持久化的场景，让本次启动固定从首个场景
        // （音乐库）开始。
        //
        // 场景是持久化的，上一次运行留下的状态会决定本次启动落在哪个场景，
        // 用例因此无法稳定复现「启动于音乐库 → 切到有声书」这条路径
        // （若上次停在有声书，App 会直接以有声书启动，走的是另一条路径）。
        if Self.shouldResetPersistedSceneForUITesting {
            resetPersistedSceneForUITestingIfNeeded()
            return
        }

        let saved = loadPersistedSceneName() ?? loadLegacySceneName()
        if let saved, let scene = AppScene(rawValue: saved), scenes.contains(scene) {
            updateCurrentScene(scene)
            return
        }

        updateCurrentScene(first)
        try? persistScene(first)
    }

    /// 忽略磁盘上持久化的场景，回到首个场景（音乐库）。
    ///
    /// UI 测试专用（`--cisum-ui-testing-reset-scene`）。
    func resetPersistedSceneForUITestingIfNeeded() {
        guard let first = scenes.first else {
            updateCurrentScene(nil)
            return
        }
        updateCurrentScene(first)
        try? persistScene(first)
    }

    /// 是否忽略持久化的场景（UI 测试专用）。
    ///
    /// 用**开关式参数**（不含 `=`）：`-key value` 形式的参数会落入
    /// UserDefaults 的「参数域」，与 `-UI.ContentViewVisible YES` 混用时
    /// 容易互相干扰；开关式参数只被 `ProcessInfo.processInfo.arguments`
    /// 消费，互不影响。
    private static var shouldResetPersistedSceneForUITesting: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("--cisum-ui-testing-reset-scene")
        #else
            false
        #endif
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        // **重放当前场景**：场景恢复发生在 `ScenePlugin.onReady`，而消费方
        // （如 `PluginAudioDBView`，`order` 更小）的 `onReady` 更早跑完——
        // 它们订阅时 `currentScene` 可能还是 `nil`，场景是在它们订阅**之后**
        // 才恢复的，恢复事件它们永远等不到，音乐库内容区就一直是空的。
        //
        // 「订阅即重放当前值」等价于订阅后立刻收到一次当前状态，
        // 消费方不必再自己补一次初值。
        if let currentScene {
            callback(.selectionChanged(scene: currentScene))
        }
        return observer
    }

    private func updateCurrentScene(_ scene: AppScene?) {
        guard currentScene != scene else { return }
        currentScene = scene
        notify(.selectionChanged(scene: scene))
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: SceneProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        for observer in observers {
            observer.observer?.invoke(event)
        }
    }

    private func loadPersistedSceneName() -> String? {
        guard let persistenceURL,
              let data = try? Data(contentsOf: persistenceURL),
              let persisted = try? JSONDecoder().decode(PersistedScene.self, from: data) else {
            return nil
        }
        return persisted.sceneName
    }

    private func loadLegacySceneName() -> String? {
        preferences.defaults.string(forKey: Self.legacySceneKey)
            ?? preferences.cloud.string(forKey: Self.legacySceneKey)
    }

    private func persistScene(_ scene: AppScene) throws {
        guard let persistenceURL else { return }
        let persisted = PersistedScene(sceneName: scene.rawValue, pluginID: nil)
        let data = try JSONEncoder().encode(persisted)

        let directory = persistenceURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: persistenceURL, options: .atomic)

        // 保留旧版键，便于从旧版本升级后继续恢复，也让已有调用方保持兼容。
        preferences.defaults.set(scene.rawValue, forKey: Self.legacySceneKey)
    }

    private final class Observer: SceneProvidingObserverHandle {
        private weak var owner: SceneProvider?
        private let callback: (SceneProvidingEvent) -> Void
        private var cancelled = false

        init(owner: SceneProvider, callback: @escaping (SceneProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: SceneProvidingEvent) {
            guard !cancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var observer: Observer?

        init(_ observer: Observer) {
            self.observer = observer
        }
    }
}