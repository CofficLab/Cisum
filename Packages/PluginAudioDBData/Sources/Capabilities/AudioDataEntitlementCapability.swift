import Foundation

/// 数据层关心的订阅权益信号：只需知道「当前是不是免费用户」。
///
/// 载荷在能力边界被抹平：数据层不关心等级枚举、不关心商店事件，
/// 只接收「是否受容量限制」这一个结论。
@MainActor
enum AudioDataEntitlementEvent {
    /// 权益发生变化（升级或降级）。
    case changed
}

/// 权益监听句柄。
@MainActor
protocol AudioDataEntitlementObserverHandle: AnyObject {
    /// 停止接收后续权益变更通知。重复调用无副作用。
    func cancel()
}

/// 数据层所需的最小订阅权益能力。
///
/// 数据层只消费「是否受容量限制」这一个结论与它的变化信号；等级枚举、
/// 商品、购买流程都不在本能力范围内。
@MainActor
protocol AudioDataEntitlementCapability: AnyObject {
    /// 当前用户是否受仓库容量限制（免费用户为 `true`）。
    var isCapacityLimited: Bool { get }

    /// 当前订阅档位的显示名。
    ///
    /// 数据层不消费等级枚举，只把它翻译成一句能直接展示的话。
    var tierDisplayName: String { get }

    /// 订阅权益变化；返回句柄需自行 `cancel()`。
    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDataEntitlementEvent) -> Void
    ) -> any AudioDataEntitlementObserverHandle
}
