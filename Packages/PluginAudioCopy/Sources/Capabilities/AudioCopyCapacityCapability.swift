import Foundation
import ProviderAudioLibrary
import ProviderStore

/// 复制功能的仓库容量准入能力。
///
/// 内核 `AudioCapacityProviding` 的判定是 `async`（要读数据库计数），
/// 复制流程需要在**排队副本之前**拿到结论。这个能力把「等判定」收敛到
/// 一处，调用方只表达意图。
@MainActor
protocol AudioCopyCapacityCapability: AnyObject, Sendable {
    /// 判定一批文件能否写入仓库。
    ///
    /// - Parameters:
    ///   - requestedCount: 请求写入的文件数量。
    ///   - reservedCount: 已被进行中复制操作占用的槽位数量。
    /// - Returns: 判定结果，含实际可写入的数量。
    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission

    /// 当前用户是否不受容量限制（付费用户）。
    var isCapacityUnlimited: Bool { get }

    /// 当前订阅档位的显示名。
    ///
    /// 限额提示里要告诉用户「你现在是什么档位」——这是引导付费的前提：
    /// 用户得先知道自己差在哪一档。
    var tierDisplayName: String { get }
}

/// 将内核 `AudioCapacityProviding` 收窄为复制功能的容量能力。
///
/// ## 惰性解析
///
/// 数据层插件的 boot 顺序不确定，复制视图贡献可能早于容量能力注册。
/// 能力内部持**惰性解析闭包**而非快照 Provider：Provider 稍后就绪时
/// 能力自动生效。
@MainActor
final class AudioCopyCapacityCapabilityAdapter: AudioCopyCapacityCapability {
    private let resolve: @MainActor @Sendable () -> (any AudioCapacityProviding)?

    init(resolve: @escaping @MainActor @Sendable () -> (any AudioCapacityProviding)?) {
        self.resolve = resolve
    }

    func admit(requestedCount: Int, reservedCount: Int) async -> AudioCapacityAdmission {
        await resolve()?.admit(requestedCount: requestedCount, reservedCount: reservedCount) ?? .admitted
    }

    var isCapacityUnlimited: Bool {
        resolve()?.isCapacityUnlimited ?? true
    }

    var tierDisplayName: String {
        resolve()?.tierDisplayName ?? SubscriptionTier.none.displayName
    }
}

/// 复制功能的购买面板呈现能力。
///
/// 撞限时给用户一条可点击的付费通路：提示「已达上限」之后，紧接着把
/// 购买面板呈现出来，而不是让用户自己去找设置里的商店入口。
@MainActor
protocol AudioCopyPurchaseCapability: AnyObject, Sendable {
    /// 呈现购买面板。
    func presentPurchase()
}

/// 将内核 `StorePurchasePresenting` 收窄为复制功能的购买能力。
@MainActor
final class AudioCopyPurchaseCapabilityAdapter: AudioCopyPurchaseCapability {
    private let resolve: @MainActor @Sendable () -> (any StorePurchasePresenting)?

    init(resolve: @escaping @MainActor @Sendable () -> (any StorePurchasePresenting)?) {
        self.resolve = resolve
    }

    func presentPurchase() {
        resolve()?.presentPurchase()
    }
}
