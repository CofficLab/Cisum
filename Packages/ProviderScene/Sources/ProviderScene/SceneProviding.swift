import Foundation
import CisumKernel
import SwiftUI

/// 场景 Provider 的语义变更事件。
@MainActor
public enum SceneProvidingEvent {
    /// 当前场景发生变化；回调执行时 `currentScene` 已更新。
    case selectionChanged(scene: AppScene?)
}

/// 场景 Provider 监听句柄。
@MainActor
public protocol SceneProvidingObserverHandle: AnyObject {
    /// 停止接收后续场景变更通知。重复调用无副作用。
    func cancel()
}

/// 场景管理服务能力协议。
///
/// 负责应用「场景」（如「音乐库」「有声书」）的激活切换与持久化恢复。
/// 场景为 Provider 内置的固定枚举（`AppScene.allCases`），不再由插件通过
/// `SuperPlugin.addSceneItem()` 动态贡献；本协议把场景管理从 `PluginProviding`
/// 中独立出来，使场景能力成为与插件 UI 聚合平行的独立 Provider，注册进
/// `CisumKernel` 后以 `kernel.scene` 暴露。
///
/// ## 使用示例
///
/// ```swift
/// let scenes = kernel.scene?.scenes ?? []
/// let current = kernel.scene?.currentScene
/// kernel.scene?.setCurrentScene(.music)
/// kernel.scene?.restoreCurrentScene()
/// ```
///
/// 协议只声明能力，不关心具体实现。使用 `AnyObject` + `ObservableObject`：
/// 协议可无泛型约束地作为存在类型（`any SceneProviding`）注册进
/// `CisumKernel` 的 Provider 注册表，并自动转发 `objectWillChange`。
@MainActor
public protocol SceneProviding: AnyObject, ObservableObject {
    /// 所有可用场景（固定内置，即 `AppScene.allCases`）。
    var scenes: [AppScene] { get }

    /// 当前激活的场景。
    var currentScene: AppScene? { get }

    /// 切换当前激活的场景（持久化）。`AppScene` 为固定枚举，入参必然有效。
    func setCurrentScene(_ scene: AppScene)

    /// 从持久化恢复当前场景；无记录或记录失效时回落到首个场景。
    func restoreCurrentScene()

    /// 注册场景状态观察者。
    ///
    /// 回调在主线程同步执行，且执行时 Provider 状态已经更新。返回的句柄
    /// 在释放或显式调用 `cancel()` 后停止接收通知。
    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle
}

public extension SceneProviding {
    /// 兼容不需要监听能力的轻量 Provider 替身。
    @discardableResult
    func addObserver(
        _ callback: @escaping (SceneProvidingEvent) -> Void
    ) -> any SceneProvidingObserverHandle {
        NoopSceneProvidingObserverHandle()
    }
}

/// 不需要语义事件实现的轻量 `SceneProviding` 替身兼容句柄。
@MainActor
public final class NoopSceneProvidingObserverHandle: SceneProvidingObserverHandle {
    public init() {}

    public func cancel() {}
}
