import Combine
import Foundation
import ProviderAppState

/// Kernel 默认提供的轻量级应用状态实现。
///
/// 吸收了旧版 `AppVM`（Demo 模式、数据库视图显隐、导入/拖放）与 `StateVM`
/// （状态消息频道）的职责，并通过 `UserDefaults` 持久化数据库视图显隐
/// （key `"UI.ShowDB"`，与旧版 `UIRepo` 一致）。
@MainActor
public final class BasicAppStateService: ObservableObject, AppStateProviding {
    private static let showDBKey = "UI.ShowDB"

    @Published public private(set) var isDemoMode = false
    @Published public private(set) var isDBViewVisible: Bool
    @Published public private(set) var isImporting = false
    @Published public private(set) var isDropping = false
    @Published public private(set) var stateMessage = ""

    private let observers = KernelEventObserverStore<AppStateProvidingEvent>()
    private let defaults: UserDefaults

    public var hasDragOperation: Bool { isDropping }

    public convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
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

    private func setDBView(_ visible: Bool) {
        guard isDBViewVisible != visible else { return }
        isDBViewVisible = visible
        defaults.set(visible, forKey: Self.showDBKey)
        observers.send(.dbViewVisibilityChanged(visible))
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (AppStateProvidingEvent) -> Void
    ) -> any AppStateProvidingObserverHandle {
        observers.add(callback)
    }
}
