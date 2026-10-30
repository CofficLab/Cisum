import Foundation
import ProviderStore

/// 将内核 `StoreEntitlementProviding` 收窄为数据层的订阅权益能力。
///
/// 数据层只问「这个用户受不受容量限制」，不问等级、不问商品。
/// 这个 Adapter 就是那条翻译层：订阅等级 → 一个布尔结论。
///
/// ## 惰性解析
///
/// 商店插件的 boot 顺序不固定（数据层可能先就绪）。这里持**惰性解析闭包**
/// 而非 Provider 快照：Provider 稍后注册时能力自动生效，无需重建数据层。
@MainActor
final class AudioDataEntitlementCapabilityAdapter: AudioDataEntitlementCapability {
    private let resolve: @MainActor @Sendable () -> (any StoreEntitlementProviding)?
    private var observers: [UUID: (AudioDataEntitlementEvent) -> Void] = [:]
    private var entitlementHandle: (any StoreEntitlementObserverHandle)?
    private var retryTask: Task<Void, Never>?

    /// 补订阅的最大重试次数；超过后仍会等待 Provider 就绪后的事件。
    private static let maxRetryCount = 10
    private static let retryInterval: UInt64 = 200_000_000

    init(resolve: @escaping @MainActor @Sendable () -> (any StoreEntitlementProviding)?) {
        self.resolve = resolve
    }

    /// 免费用户受容量限制；付费用户不受限。
    ///
    /// Provider 尚未就绪时按「受限」处理：宁可先挡住也不要让免费用户
    /// 绕过上限——等到 Provider 就绪后判定会自动修正。
    var isCapacityLimited: Bool {
        guard let entitlement = resolve() else { return true }
        return entitlement.tier.isFreeVersion
    }

    /// 当前档位显示名；Provider 未就绪时按免费档展示。
    var tierDisplayName: String {
        guard let entitlement = resolve() else { return SubscriptionTier.none.displayName }
        return entitlement.tier.displayName
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDataEntitlementEvent) -> Void
    ) -> any AudioDataEntitlementObserverHandle {
        let token = UUID()
        observers[token] = callback
        subscribeIfPossible()
        return AudioDataEntitlementHandleBox { [weak self] in
            self?.observers[token] = nil
        }
    }

    /// 订阅商店权益事件；Provider 尚未注册时稍后重试补订阅。
    private func subscribeIfPossible() {
        guard entitlementHandle == nil else { return }
        guard let entitlement = resolve() else {
            scheduleRetry()
            return
        }

        entitlementHandle = entitlement.addObserver { [weak self] _ in
            self?.publishChange()
        }
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

    /// 派发权益变化。
    private func publishChange() {
        for callback in observers.values {
            callback(.changed)
        }
    }
}

/// 将商店的权益句柄适配为本插件的句柄类型，
/// 避免 Provider 的句柄类型泄漏到能力协议之外。
@MainActor
private final class AudioDataEntitlementHandleBox: AudioDataEntitlementObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: @escaping () -> Void) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
