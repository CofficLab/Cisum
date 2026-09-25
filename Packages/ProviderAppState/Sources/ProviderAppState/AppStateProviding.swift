import Foundation

@MainActor
public enum AppStateProvidingEvent {
    case demoModeChanged(Bool)
    case dbViewVisibilityChanged(Bool)
    case importingChanged(Bool)
    case droppingChanged(Bool)
    case stateMessageChanged(String)
}

@MainActor
public protocol AppStateProvidingObserverHandle: AnyObject {
    func cancel()
}

/// 应用状态服务能力协议。
///
/// 提供应用级的 UI 状态管理，吸收了旧版 `AppVM`（Demo 模式、数据库视图、
/// 导入/拖放）与 `StateVM`（状态消息频道）的字段。
///
/// ## 使用示例
///
/// ```swift
/// kernel.resolveProvider((any AppStateProviding).self)?.enterDemoMode()
/// let isDemo = kernel.resolveProvider((any AppStateProviding).self)?.isDemoMode ?? false
/// kernel.resolveProvider((any AppStateProviding).self)?.appendStateMessage("Imported 3 files")
/// ```
@MainActor
public protocol AppStateProviding: AnyObject, ObservableObject {
    /// 是否处于 Demo 模式。
    var isDemoMode: Bool { get }

    /// 数据库视图是否可见。
    var isDBViewVisible: Bool { get }

    /// 是否正在进行导入操作。
    var isImporting: Bool { get }

    /// 是否有正在进行中的拖放操作。
    var isDropping: Bool { get }

    /// 是否有正在进行中的拖放/拖拽操作（兼容别名）。
    var hasDragOperation: Bool { get }

    /// 当前状态栏消息。
    var stateMessage: String { get }

    /// 进入 Demo 模式。
    func enterDemoMode()

    /// 退出 Demo 模式。
    func exitDemoMode()

    /// 显示数据库视图。
    func showDBView()

    /// 隐藏数据库视图。
    func hideDBView()

    /// 关闭数据库视图（同 hide）。
    func closeDBView()

    /// 切换数据库视图显隐。
    func toggleDBView()

    /// 更新导入状态。
    func setImporting(_ importing: Bool)

    /// 更新拖放状态。
    func setDragOperation(_ active: Bool)

    /// 追加一条状态消息。
    func appendStateMessage(_ message: String)

    /// 清空状态消息。
    func clearStateMessages()

    /// 注册应用状态观察者。
    @discardableResult
    func addObserver(_ callback: @escaping (AppStateProvidingEvent) -> Void) -> any AppStateProvidingObserverHandle
}

public extension AppStateProviding {
    @discardableResult
    func addObserver(_ callback: @escaping (AppStateProvidingEvent) -> Void) -> any AppStateProvidingObserverHandle {
        NoopAppStateProvidingObserverHandle()
    }
}

@MainActor
public final class NoopAppStateProvidingObserverHandle: AppStateProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
