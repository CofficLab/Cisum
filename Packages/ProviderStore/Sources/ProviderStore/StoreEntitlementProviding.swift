import Foundation

/// 订阅权益发生变化时对外发布的事件。
///
/// 事件只携带**变化后的等级**，不暴露 StoreKit 交易、订阅组或续期信息——
/// 消费方需要回答的问题是「当前还能不能用受限功能」，而不是
/// 「这笔交易是怎么来的」。
public enum StoreEntitlementEvent: Sendable {
    /// 当前订阅等级发生变化（升级、降级、过期或恢复购买）。
    case tierChanged(SubscriptionTier)
}

/// 订阅权益监听句柄。
@MainActor
public protocol StoreEntitlementObserverHandle: AnyObject {
    /// 停止接收后续权益变更事件。重复调用无副作用。
    func cancel()
}

/// 订阅权益能力协议。
///
/// 只回答一个问题：**当前用户是什么订阅等级**。
///
/// 这是刻意做窄的边界：仓库容量之类的业务规则要判断「要不要给这个人
/// 设上限」，只需要知道「他是不是免费用户」。让消费方直接依赖
/// `StoreService` 会把整套 StoreKit 生命周期（交易监听、权益校准、
/// 商品拉取）拖进每一个调用点，而这些都不是它们关心的。
///
/// ## 线程语义
/// 与内核其他 Provider 一致：主线程语义（`@MainActor`）。
/// 权益变化在主线程派发，消费方不必再加一层线程切换。
@MainActor
public protocol StoreEntitlementProviding: AnyObject, Sendable {
    /// 当前订阅等级。
    ///
    /// 过期订阅返回 `.none`——过期即等价于免费档，而不是「曾经买过」。
    var tier: SubscriptionTier { get }

    /// 订阅权益变更事件。
    @discardableResult
    func addObserver(
        _ callback: @escaping (StoreEntitlementEvent) -> Void
    ) -> any StoreEntitlementObserverHandle
}

public extension StoreEntitlementProviding {
    /// 默认实现不派发任何事件：测试替身与尚未就绪的实现方落到这里。
    @discardableResult
    func addObserver(
        _ callback: @escaping (StoreEntitlementEvent) -> Void
    ) -> any StoreEntitlementObserverHandle {
        NoopStoreEntitlementObserverHandle()
    }
}

/// 空实现句柄：用于「订阅能力存在但没有事件可派发」的场合。
@MainActor
public final class NoopStoreEntitlementObserverHandle: StoreEntitlementObserverHandle {
    public init() {}
    public func cancel() {}
}
