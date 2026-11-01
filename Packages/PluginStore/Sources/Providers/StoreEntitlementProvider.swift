import Foundation
import ProviderStore
import ProviderStoreKit

/// `StoreEntitlementProviding` 的实现：把 StoreKit 权益收敛成一个等级结论。
///
/// ## 为什么单独一层
///
/// `StoreService` 是一整套 StoreKit 生命周期（交易监听、权益校准、商品拉取、
/// 购买）。容量规则之类的消费方只想知道「这个人是不是免费用户」，让它们直接
/// 依赖 `StoreService` 会把整套生命周期拖进每个调用点。
///
/// 这一层只做两件事：
/// 1. 把权益读成**一个等级**（`tier`），并抹掉「过期即免费」的判断细节；
/// 2. 在等级变化时派发事件，让限额界面能立刻刷新。
///
/// ## 数据来源
///
/// 等级的真值仍然是 `StoreState`（UserDefaults 持久化 + `currentEntitlements`
/// 校准）。这里**不缓存等级**，每次 `tier` 都直接读 `StoreState`：权益是
/// 会被 StoreKit 在任意时刻改写（购买、过期、恢复、退款）的状态，缓存一份
/// 副本等于把「过期了但仍按 Pro 放行」变成常态。
@MainActor
public final class StoreEntitlementProvider: StoreEntitlementProviding {
    private let readEntitlement: @MainActor () -> StoreEntitlementSnapshot
    private var observers: [UUID: (StoreEntitlementEvent) -> Void] = [:]
    private var notificationToken: NSObjectProtocol?

    /// 上一次派发出去的等级，用于去重。
    ///
    /// 初始化为「当前等级」而不是 `.none`：Provider 构造时权益可能已经是 Pro，
    /// 此时不应因为「第一次读到 Pro」就当成一次变化派发。
    private var lastPublishedTier: StoreTier

    /// - Parameter readEntitlement: 读取当前权益快照的闭包。默认直接读 `StoreState`。
    public init(
        readEntitlement: @escaping @MainActor () -> StoreEntitlementSnapshot = {
            StoreService.currentEntitlement()
        }
    ) {
        self.readEntitlement = readEntitlement
        self.lastPublishedTier = readEntitlement().effectiveTier
        observeStoreTransactions()
    }

    /// 停止监听交易更新。
    ///
    /// 显式清理而非 `deinit`：Swift 6 的 `deinit` 是 nonisolated 的，
    /// 访问 `NSObjectProtocol`（非 Sendable）属性不合法。Provider 生命周期
    /// 由插件入口管理，关闭时显式调用本方法即可。
    public func shutdown() {
        if let notificationToken {
            NotificationCenter.default.removeObserver(notificationToken)
            self.notificationToken = nil
        }
        observers.removeAll()
    }

    // MARK: - StoreEntitlementProviding

    /// 权益快照是唯一真值；`tier` 由共享契约的默认实现派生（过期即免费）。
    public var entitlement: StoreEntitlementSnapshot {
        readEntitlement()
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (StoreEntitlementEvent) -> Void
    ) -> any StoreEntitlementObserverHandle {
        let token = UUID()
        observers[token] = callback
        return StoreEntitlementObserverHandleBox { [weak self] in
            self?.observers[token] = nil
        }
    }

    // MARK: - Transaction observation

    /// 监听交易更新：StoreKit 交易落地时权益可能变了（购买成功、续期、退款）。
    ///
    /// 恢复购买走的是 `AppStore.sync()`，它同样会推送交易更新，因此这条通路
    /// 覆盖「恢复」场景，不需要另开一个通知。
    private func observeStoreTransactions() {
        notificationToken = NotificationCenter.default.addObserver(
            forName: .storeTransactionUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.publishTierChange()
            }
        }
    }

    /// 派发等级变化（仅在真的变了时）。
    private func publishTierChange() {
        let current = tier
        guard current != lastPublishedTier else { return }
        lastPublishedTier = current

        for callback in observers.values {
            callback(.tierChanged(current))
        }
    }
}

// MARK: - Handle

/// 权益监听句柄实现：取消即从观察者表里摘除。
@MainActor
private final class StoreEntitlementObserverHandleBox: StoreEntitlementObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: @escaping () -> Void) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
