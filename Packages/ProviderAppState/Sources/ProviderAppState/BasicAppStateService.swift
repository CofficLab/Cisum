import Combine
import Foundation
import KitEventObservation

/// Kernel 默认提供的轻量级应用状态实现。
///
/// 吸收了旧版 `AppVM`（Demo 模式、数据库视图显隐、导入/拖放）与 `StateVM`
/// （状态消息频道）的职责，并通过 `UserDefaults` 持久化数据库视图显隐
/// （key `"UI.ContentViewVisible"`）。
@MainActor
public final class BasicAppStateService: ObservableObject, AppStateProviding {
    /// 内容区（音乐库）显隐的持久化键。
    ///
    /// 历史键 `"UI.ShowDB"` **不再读取**。旧值有两种来源且无法区分：
    /// - 用户主动收起内容区（真实意图，应当保留）；
    /// - 已知缺陷写坏的值——p4.4.3 之前的 iOS 几何规则会在启动 / 旋转期把内容区
    ///   误收起（`RootContentVisibility` 修复前该路径对所有平台生效），
    ///   重构前的桌面 `UIRepo` 也把同一个键写成 `false`。
    ///
    /// 沿用旧键会让「升级后每次冷启动只剩空播放器」永久成立，且用户无法分辨
    /// 自己是否主动收起过。新键不复用旧值：一律以「内容区可见」起步，
    /// 之后只记录用户自己的显式操作。
    private static let showDBKey = "UI.ContentViewVisible"

    @Published public private(set) var isDemoMode = false
    @Published public private(set) var isDBViewVisible: Bool
    @Published public private(set) var isImporting = false
    @Published public private(set) var isDropping = false
    @Published public private(set) var stateMessage = ""

    private let observers = EventObserverStore<AppStateProvidingEvent>()
    private let defaults: UserDefaults

    public var hasDragOperation: Bool { isDropping }

    public convenience init() {
        self.init(defaults: .standard)
    }

    /// 指定 `UserDefaults` 存储。生产用 `init()`，测试可注入独立 suite 隔离偏好。
    public init(defaults: UserDefaults) {
        self.defaults = defaults
        // A fresh install should open on its library scene. Preserve an explicit
        // false value so users who collapsed the content area keep that choice.
        isDBViewVisible = defaults.object(forKey: Self.showDBKey) as? Bool ?? true
    }

    public func enterDemoMode() {
        guard !isDemoMode else { return }
        isDemoMode = true
        observers.send(.demoModeChanged(true))
    }

    public func exitDemoMode() {
        guard isDemoMode else { return }
        isDemoMode = false
        observers.send(.demoModeChanged(false))
    }

    public func showDBView() {
        setDBView(true)
    }

    public func hideDBView() {
        setDBView(false)
    }

    public func closeDBView() {
        setDBView(false)
    }

    public func toggleDBView() {
        setDBView(!isDBViewVisible)
    }

    /// 显式设置内容区显隐，并持久化。
    ///
    /// 与 `showDBView()` / `hideDBView()` 走同一条路径（落盘 + 广播），
    /// 只是目标态由调用方给出。
    public func setDBView(_ visible: Bool) {
        guard isDBViewVisible != visible else { return }
        isDBViewVisible = visible
        defaults.set(visible, forKey: Self.showDBKey)
        observers.send(.dbViewVisibilityChanged(visible))
    }

    public func setImporting(_ importing: Bool) {
        guard isImporting != importing else { return }
        isImporting = importing
        observers.send(.importingChanged(importing))
    }

    public func setDragOperation(_ active: Bool) {
        guard isDropping != active else { return }
        isDropping = active
        observers.send(.droppingChanged(active))
    }

    public func appendStateMessage(_ message: String) {
        if stateMessage.isEmpty {
            stateMessage = message
        } else {
            stateMessage += "\n" + message
        }
        observers.send(.stateMessageChanged(stateMessage))
    }

    public func clearStateMessages() {
        guard !stateMessage.isEmpty else { return }
        stateMessage = ""
        observers.send(.stateMessageChanged(stateMessage))
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (AppStateProvidingEvent) -> Void
    ) -> any AppStateProvidingObserverHandle {
        observers.add(callback)
    }
}
