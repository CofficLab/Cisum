import Foundation
import ProviderAudioLibrary

/// 容量额度观察句柄。
@MainActor
public protocol AudioCapacityObserverHandle: AnyObject {
    /// 停止接收后续额度变化通知。重复调用无副作用。
    func cancel()
}

/// 仓库容量准入 Provider：把「容量真值」与「订阅权益」合成一个判定。
///
/// ## 判定规则
///
/// ```
/// 付费用户  → 无限额，全部放行
/// 免费用户  → 上限 = freeTierFileLimit
///             剩余额度 = 上限 - (仓库已有数 + 进行中操作占用数)
///             放行数 = min(请求数, max(0, 剩余额度))
/// ```
///
/// ## 为什么占用数由调用方传入
///
/// 复制是异步的：文件真正落盘之前，操作已经「占了位」。如果只看仓库里
/// 已有的文件数，连续两次拖放都会读到同一个计数，从而双双放行，最终超限。
///
/// 但只有**知道自己在排队副本**的操作方才有这个信息——数据层看不到
/// 别人排队的任务。因此由调用方传入 `reservedCount`，闸门只负责把
/// 「已有数 + 占用数」合成额度。
///
/// ## 为什么不缓存仓库计数
///
/// 仓库计数来自数据库查询（`totalCount()`）。缓存一份副本看起来省事，
/// 但它必须在每次同步、删除之后被正确更新——漏一次就会让额度算错，
/// 而额度算错的表现是「免费用户能突破上限」或「付费用户被误挡」。
/// 与其维护一份必须时刻正确的影子状态，不如直接问数据层要真值。
///
/// ## 为什么权益变化要重算
///
/// 用户在撞限后购买订阅，额度应当立刻放宽。权益变化事件让数据层重新
/// 计算额度，而不是等下次写入才生效——否则用户付了钱却还要再试一次。
@MainActor
final class AudioCapacityProvider: AudioCapacityProviding {
    private let library: any AudioLibraryProviding
    private let entitlement: any AudioDataEntitlementCapability

    /// 权益变化时重算并回调，让关心额度的消费方刷新。
    private var entitlementHandle: (any AudioDataEntitlementObserverHandle)?
    private var capacityObservers: [UUID: (Int) -> Void] = [:]

    init(
        library: any AudioLibraryProviding,
        entitlement: any AudioDataEntitlementCapability
    ) {
        self.library = library
        self.entitlement = entitlement
        observeEntitlementChanges()
    }

    func shutdown() {
        entitlementHandle?.cancel()
        entitlementHandle = nil
        capacityObservers.removeAll()
    }

    // MARK: - AudioCapacityProviding

    var freeTierFileLimit: Int {
        AudioPluginInfo.maxAudioCount
    }

    var isCapacityUnlimited: Bool {
        !entitlement.isCapacityLimited
    }

    var tierDisplayName: String {
        entitlement.tierDisplayName
    }

    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission {
        guard requestedCount > 0 else { return .admitted }
        guard !isCapacityUnlimited else { return .admitted }

        let occupied = await library.totalCount() + max(0, reservedCount)
        let remaining = max(0, freeTierFileLimit - occupied)
        let allowed = min(requestedCount, remaining)

        if allowed == requestedCount {
            return .admitted
        }
        if allowed == 0 {
            return .rejected
        }
        return .partiallyAdmitted(allowedCount: allowed)
    }

    /// 剩余额度（供 UI 展示「还剩几个」）。
    func freeTierRemaining() async -> Int {
        guard !isCapacityUnlimited else { return .max }
        let occupied = await library.totalCount()
        return max(0, freeTierFileLimit - occupied)
    }

    /// 订阅额度变化通知；回调携带新的剩余额度。
    @discardableResult
    func addCapacityObserver(
        _ callback: @escaping (Int) -> Void
    ) -> any AudioCapacityObserverHandle {
        let token = UUID()
        capacityObservers[token] = callback
        return AudioCapacityObserverHandleBox { [weak self] in
            self?.capacityObservers[token] = nil
        }
    }

    // MARK: - Entitlement observation

    /// 权益变化时重算额度并通知消费方。
    private func observeEntitlementChanges() {
        entitlementHandle = entitlement.addObserver { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshRemaining()
            }
        }
    }

    /// 重新计算剩余额度并派发。
    private func refreshRemaining() async {
        let remaining = await freeTierRemaining()
        for callback in capacityObservers.values {
            callback(remaining)
        }
    }
}

/// 容量观察句柄实现：取消即从观察者表里摘除。
@MainActor
final class AudioCapacityObserverHandleBox: AudioCapacityObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: @escaping () -> Void) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
