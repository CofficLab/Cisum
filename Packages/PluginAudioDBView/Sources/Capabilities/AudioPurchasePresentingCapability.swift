import Foundation
import ProviderStore

/// 购买面板呈现能力（插件侧）。
///
/// 内核 `StorePurchasePresenting` 直接就是「请商店弹购买面板」这一个动作，
/// 这里只做一层薄封装，让视图层的依赖结构能显式声明「本插件会引导付费」。
@MainActor
public protocol AudioPurchasePresentingCapability: AnyObject, Sendable {
    /// 呈现购买面板。
    func presentPurchase()
}

/// 将内核 `StorePurchasePresenting` 收窄为插件的购买呈现能力。
///
/// ## 惰性解析
///
/// 商店插件的 boot 顺序不确定。能力内部持**惰性解析闭包**而非快照
/// Provider：Provider 稍后就绪时能力自动生效，商店插件缺席时静默降级
/// （撞限提示仍然显示，只是没有购买入口）。
@MainActor
final class AudioPurchasePresentingCapabilityAdapter: AudioPurchasePresentingCapability {
    private let resolve: @MainActor @Sendable () -> (any StorePurchasePresenting)?

    init(resolve: @escaping @MainActor @Sendable () -> (any StorePurchasePresenting)?) {
        self.resolve = resolve
    }

    func presentPurchase() {
        resolve()?.presentPurchase()
    }
}
