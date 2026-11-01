import Foundation
import ProviderStore

// MARK: - Cisum Store Catalog

/// Cisum 的商品表：商品 ID → 订阅档位。
///
/// ## 为什么商品表留在 App 侧
///
/// 商品 ID 是 Cisum 商店后台的配置，不属于共享层。共享层（`ProviderStore`
/// 契约 + `KitStoreKit` 机制）只定义**映射的形状**（`StoreProductCatalog`），
/// 由本类型提供具体取值。
///
/// ## 为什么这里是唯一真值源
///
/// 商品 ID 集合历史上散落两处（`StoreConfig` 与 `.storekit`），各自漂移。
/// 漂移的后果不是「配置不好看」，而是**付费链路静默断裂**：
///
/// - 商品在 `.storekit` 里但不在 `productTier` 里 → `tier(for:)` 返回 `.none`
///   → 权益判定直接跳过 → **用户付了钱，权益没到账**；
/// - 商品在 `productTier` 里但线上没有 → `Product.products(for:)` 请求失败
///   → 购买面板加载不出来。
///
/// 因此这里只保留**一份** ID 集合，并用测试守住它与 `.storekit` 配置一致。
public struct CisumStoreCatalog: StoreProductCatalog {
    /// 商品 ID → 订阅档位。
    ///
    /// - `.pro`：授予 Pro 权益（解除仓库容量限制等）。
    /// - `.none`：不授予任何等级。消耗品与非消耗品占位商品属于这一类——
    ///   它们不提供订阅权益，列出它们只是为了在配置里保留位置。
    public let productTiers: [String: StoreTier]

    public init(productTiers: [String: StoreTier]) {
        self.productTiers = productTiers
    }

    /// 商品表本体：全量商品 ID 与档位映射。
    ///
    /// - `.pro`：授予 Pro 权益（解除仓库容量限制等）。
    /// - `.none`：不授予任何等级。消耗品与非消耗品占位商品属于这一类——
    ///   它们不提供订阅权益，列出它们只是为了在配置里保留位置。
    public static let shared = CisumStoreCatalog(productTiers: [
        // Consumables
        "consumable.fuel.octane87": .none,
        "consumable.fuel.octane89": .none,
        "consumable.fuel.octane91": .none,

        // Non-consumables
        "nonconsumable.car": .none,
        "nonconsumable.utilityvehicle": .none,
        "nonconsumable.racecar": .none,

        // Auto-renewable subscriptions — Cisum
        //
        // 这两个是 App Store Connect 上 Cisum（com.yueyi.cisum）真实在售的
        // 自动续期商品，也是购买面板应当展示的两档。
        //
        // 历史上这里还映射了 .pro.monthly / .pro.yearly / .pro.annual / .annual
        // 四个 ID，但它们从未在 App Store Connect 上架过。保留这些映射会让
        // 购买面板按 `allProductIds` 请求一批永远拿不到的商品，并把本地
        // mock 的档位数量推到 6 行，与生产的 2 行不一致。
        "com.yueyi.cisum.monthly": .pro,
        "com.yueyi.cisum.yearly": .pro,

        // Non-renewing subscriptions — Cisum
        "com.yueyi.cisum.pro.month.1": .pro,
        "com.yueyi.cisum.pro.year.1": .pro,
        "com.yueyi.cisum.pro.day.7": .pro,

        // Non-renewing subscriptions — 快易知（同一订阅体系的历史商品 ID）
        //
        // 这些 ID 必须在映射里：`.storekit` 配置里存在它们，若缺少映射则
        // `tier(for:)` 返回 `.none`，用户购买后权益不会授予。
        "com.yueyi.kuaiyizhi.pro.month.1": .pro,
        "com.yueyi.kuaiyizhi.pro.year.1": .pro,
        "com.yueyi.kuaiyizhi.pro.day.7": .pro,
    ])
}
