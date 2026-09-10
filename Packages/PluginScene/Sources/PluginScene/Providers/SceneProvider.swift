import Combine
import Foundation
import ProviderScene

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

    private let persistenceURL: URL?
    private var observers: [WeakObserver] = []

    @Published public private(set) var currentScene: AppScene?

    /// - Parameter pluginDataDirectory: 插件专属数据目录
    ///   （由 `StorageProviding.pluginDataDirectory(for: pluginID)` 解析得到）。
    ///   传 `nil` 时禁用磁盘持久化（仅内存态，用于 onBoot 阶段 Storage 尚未就绪时）。
    public init(pluginDataDirectory: URL?) {
        self.persistenceURL = pluginDataDirectory?
            .appendingPathComponent(Self.persistenceFileName, isDirectory: false)
        self.currentScene = nil
    }

    public var scenes: [AppScene] {
        AppScene.allCases
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

        let saved = loadPersistedSceneName() ?? loadLegacySceneName()
        if let saved, let scene = AppScene(rawValue: saved), scenes.contains(scene) {
            updateCurrentScene(scene)
            return
        }

        updateCurrentScene(first)
        try? persistScene(first)
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
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
        UserDefaults.standard.string(forKey: Self.legacySceneKey)
            ?? NSUbiquitousKeyValueStore.default.string(forKey: Self.legacySceneKey)
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
        UserDefaults.standard.set(scene.rawValue, forKey: Self.legacySceneKey)
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
