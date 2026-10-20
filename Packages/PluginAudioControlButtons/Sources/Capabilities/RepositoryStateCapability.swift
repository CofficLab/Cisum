import Foundation
import ProviderAudioLibrary

/// 仓库空/非空状态事件。
@MainActor
enum RepositoryStateEvent: Sendable {
    /// 仓库确认为空。
    case empty
    /// 仓库恢复为非空。
    case filled
}

/// 仓库状态监听句柄。
@MainActor
protocol RepositoryStateObserverHandle: AnyObject {
    /// 停止接收后续仓库状态事件。重复调用无副作用。
    func cancel()
}

/// 「更多」按钮引导所需的最小仓库状态能力。
///
/// 只暴露「仓库是否为空」这一个结论及其变化：控制按钮不关心仓库里有哪些
/// 文件，也不负责导入——它只在该结论为真时给「⋯」按钮加一层引导。
@MainActor
protocol RepositoryStateCapability: AnyObject {
    /// 仓库是否确认为空。
    var isEmpty: Bool { get }

    /// 订阅仓库空/非空状态变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (RepositoryStateEvent) -> Void
    ) -> any RepositoryStateObserverHandle
}

/// 将内核 `AudioLibraryProviding` 收窄为「仓库是否为空」的能力。
///
/// 内部持**惰性解析闭包**而非 Provider 快照：数据层插件（注册
/// `AudioLibraryProviding`）与本插件的装配顺序不固定，快照会让能力在
/// Provider 稍后就绪时永久失效。
///
/// 空/非空结论**不自己解释计数**，而是直接读数据层给出的
/// `isRepositoryEmpty`：数据层知道仓库扫完了没有（未扫描时计数同样是 0，
/// 那是「还不知道」而不是「是空的」）。本能力只在仓库事件到来时刷新一次
/// 结论，结论没变就不广播。
@MainActor
final class RepositoryStateCapabilityAdapter: RepositoryStateCapability {
    private let resolve: @MainActor @Sendable () -> (any AudioLibraryProviding)?

    /// 当前结论；初始为「非空」——尚未收到任何结论时不该显示引导。
    private(set) var isEmpty = false

    private var observers: [UUID: (RepositoryStateEvent) -> Void] = [:]
    private var libraryHandle: (any AudioLibraryProvidingObserverHandle)?
    private var retryTask: Task<Void, Never>?

    /// 补订阅的最大重试次数；超过后仍会等待 Provider 就绪后的事件。
    private static let maxRetryCount = 10
    private static let retryInterval: UInt64 = 200_000_000

    init(resolve: @escaping @MainActor @Sendable () -> (any AudioLibraryProviding)?) {
        self.resolve = resolve
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (RepositoryStateEvent) -> Void
    ) -> any RepositoryStateObserverHandle {
        let token = UUID()
        observers[token] = callback
        subscribeIfPossible()
        return RepositoryStateObserverHandleBox { [weak self] in
            self?.observers[token] = nil
        }
    }

    /// 订阅仓库事件；Provider 尚未注册时稍后重试补订阅。
    private func subscribeIfPossible() {
        guard libraryHandle == nil else { return }
        guard let library = resolve() else {
            scheduleRetry()
            return
        }

        libraryHandle = library.addObserver { [weak self] event in
            self?.refresh()
        }
        refresh()
    }

    /// 延迟重试补订阅（Provider 注册可能晚于本插件 boot）。
    private func scheduleRetry() {
        guard retryTask == nil else { return }

        retryTask = Task { @MainActor [weak self] in
            for _ in 0 ..< Self.maxRetryCount {
                try? await Task.sleep(nanoseconds: Self.retryInterval)
                guard let self else { return }
                guard self.observers.isEmpty == false else { return }
                guard self.resolve() != nil else { continue }
                self.subscribeIfPossible()
                return
            }
        }
    }

    /// 刷新结论：读数据层的判定，只有结论变化才广播。
    private func refresh() {
        guard let library = resolve() else { return }
        publish(library.isRepositoryEmpty ? .empty : .filled)
    }

    private func publish(_ event: RepositoryStateEvent) {
        let nextIsEmpty: Bool
        switch event {
        case .empty: nextIsEmpty = true
        case .filled: nextIsEmpty = false
        }
        guard nextIsEmpty != isEmpty else { return }

        isEmpty = nextIsEmpty
        for callback in observers.values {
            callback(event)
        }
    }
}

/// 将仓库状态句柄适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class RepositoryStateObserverHandleBox: RepositoryStateObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: @escaping () -> Void) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
