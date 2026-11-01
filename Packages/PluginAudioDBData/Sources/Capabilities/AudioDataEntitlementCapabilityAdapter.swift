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
    /// 当前订阅所绑定的 Provider 实例。
    ///
    /// 插件可在运行时被停用 / 启用（插件管理页）。商店插件被停用时会
    /// `unregisterProvider`，启用时会**注册一个新的 Provider 实例**。
    /// 若不记住绑定了哪个实例，重启后就会继续监听已被注销的旧实例——
    /// 权益变化事件从此静默丢失。
    private var subscribedProvider: (any StoreEntitlementProviding)?
    private var retryTask: Task<Void, Never>?

    /// 复查 Provider 实例的间隔。
    ///
    /// 间隔不宜太长（用户升级订阅后容量上限应及时放开），
    /// 也不宜太短（避免无谓的轮询开销）。
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
        return entitlement.tier.isFree
    }

    /// 当前档位显示名；Provider 未就绪时按免费档展示。
    var tierDisplayName: String {
        guard let entitlement = resolve() else { return StoreTier.none.defaultDisplayName }
        return entitlement.tier.defaultDisplayName
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (AudioDataEntitlementEvent) -> Void
    ) -> any AudioDataEntitlementObserverHandle {
        let token = UUID()
        observers[token] = callback
        subscribeIfPossible()
        startWatchingIfNeeded()
        return AudioDataEntitlementHandleBox { [weak self] in
            self?.observers[token] = nil
        }
    }

    /// 订阅商店权益事件；Provider 尚未注册时稍后重试补订阅。
    ///
    /// Provider 实例发生变化时（插件重启）会**重新订阅**：旧句柄属于已被
    /// 注销的实例，继续持有只会让权益变化事件静默丢失。
    private func subscribeIfPossible() {
        guard let entitlement = resolve() else {
            return
        }

        if let subscribedProvider, subscribedProvider === entitlement {
            // 已订阅当前实例，无需重复订阅。
            return
        }

        // Provider 实例已更换：退订旧实例，再绑定新实例。
        entitlementHandle?.cancel()
        entitlementHandle = nil
        subscribedProvider = entitlement

        entitlementHandle = entitlement.addObserver { [weak self] _ in
            self?.publishChange()
        }
    }

    /// 启动 Provider 监听循环。
    ///
    /// Provider 的注册时机不可控：商店插件可能晚于本插件 boot，也可能被
    /// 用户在插件管理页停用后重新启用（此时注册的是**新实例**）。
    /// 因此这里持续复查 Provider 实例，发生变化就重新订阅——
    /// 否则用户升级订阅后，容量上限会一直按免费档计算。
    private func startWatchingIfNeeded() {
        guard retryTask == nil else { return }
        guard observers.isEmpty == false else { return }

        retryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.retryInterval)
                guard let self else { return }
                // 没有订阅者时停止监听，避免无谓的轮询。
                guard self.observers.isEmpty == false else { return }
                self.subscribeIfPossible()
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
