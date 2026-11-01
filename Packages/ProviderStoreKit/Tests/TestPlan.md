# TestPlan — ProviderStore

## 包概述

ProviderStore 封装 StoreKit 2 内购与订阅能力:商品抓取与分组、交易校验、订阅状态检查、权益(Entitlement)探测与本地缓存,并广播交易更新通知。测试重点覆盖**纯逻辑**(权益判定、tier 归并、分组、过期回退),网络/真实交易路径依赖 StoreKit 运行环境。

核心组件:
- `PurchaseInfo` / `SubscriptionTier` - 权益快照与订阅等级
- `StoreConfig` - productID → tier 映射与全量 productID 列表
- `StoreService` - 交易监听、商品抓取、订阅状态检查、校验与过期回退
- `StoreState` - 权益缓存读写、`detectedPurchaseInfo`、非续订权益判定
- `ProductGroupsDTO` / `SubscriptionGroupDTO` / `ProductDTO` / `SubscriptionInfoDTO` / `StoreSubscriptionPeriodDTO` / `StoreSubscriptionStatusDTO`
- `StoreError` / `StorePluginInfo` / `Notification.Name` 扩展

## 测试用例清单

| ID | 类别 | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|------|------|----------|
| 1 | 权益 | `PurchaseInfo` 依 tier 与到期时间解析 `isProOrHigher`/`isExpired`/`effectiveTier`/`expiresAtString` | P0 | ✅ 已覆盖 | `purchaseInfoResolvesEntitlementAndExpiry` |
| 2 | 等级 | `SubscriptionTier` 排序、`isFreeVersion`/`isProOrHigher`/`isUltimateOrHigher`、`displayName`、Codable 稳定 | P0 | ✅ 已覆盖 | `subscriptionTierOrderingDisplayAndCodableAreStable` |
| 3 | 配置 | `StoreConfig.allProductIds` 完整;`tier(for:)` 与 `StoreService.tier(for:)` 映射正确,未知→`.none` | P0 | ✅ 已覆盖 | `productConfigurationContainsMappedProductIDs` |
| 4 | DTO | `ProductGroupsDTO` 展平订阅、按 id 查找分组、空分组返回空 | P1 | ✅ 已覆盖 | `productGroupsFlattenSubscriptionsAndFindGroups` |
| 5 | DTO | 分类商品拆入 cars/subscriptions/nonRenewables/fuel | P1 | ✅ 已覆盖 | `classifiedProductsAreSeparatedIntoStoreCategories` |
| 6 | DTO | 按订阅组元数据分组并按价格排序,无组归入 unknown | P1 | ✅ 已覆盖 | `subscriptionGroupingUsesGroupMetadataAndSortsPrices` |
| 7 | DTO | `StoreSubscriptionPeriodDTO` Codable 稳定;`Unit.description` 固定 | P2 | ✅ 已覆盖 | `subscriptionPeriodDTOEncodesStableValues` |
| 8 | 服务 | `highestActiveSubscriptionStatusIndex` 跳过 expired/revoked/nil/未知产品,取最高 tier 索引 | P0 | ✅ 已覆盖 | `highestActiveSubscriptionSkipsExpiredRevokedAndUnknownProducts` |
| 9 | 状态 | `StoreState` 权益读写/清除持久化到 UserDefaults,非法数据回落 `.none` | P0 | ✅ 已覆盖 | `storeStatePersistsAndClearsPurchaseInfo` / `storeStateClearResetsToNone` |
| 10 | 状态 | 过期/无到期时间的非续订权益不授予 tier;有效则授予 | P0 | ✅ 已覆盖 | `expiredNonRenewableEntitlementsDoNotGrantSubscriptionTier` / `nonRenewableEntitlementRequiresFutureExpiration` |
| 11 | 状态 | `detectedPurchaseInfo` 归并最高 tier 与最晚有效到期;忽略过期非续订;空输入→`.none` | P0 | ✅ 已覆盖 | `entitlementCalibrationKeepsHighestTierAndLatestValidExpiration` / `entitlementDetectionMergesTiersAndMaxExpiration` / `entitlementDetectionIgnoresExpiredNonRenewable` / `entitlementDetectionCountsActiveNonRenewable` |
| 12 | 服务 | `checkVerified` 校验通过/抛出;`computeExpirationDate(nil)`→distantPast;监听启动条件 | P0 | ✅ 已覆盖 | `storeServiceHelpersHandleVerificationAndExpirationFallback` |
| 13 | 元信息 | `StorePluginInfo` 常量、`StoreError` 本地化描述、`Notification.Name` 原始值稳定;`onRestored`/`onStoreTransactionUpdated` 可编译 | P1 | ✅ 已覆盖 | `storeMetadataErrorsAndNotificationNamesRemainStable` |
| 14 | 通知 | `postTransactionUpdated` 广播携带 productID | P1 | ✅ 已覆盖 | `transactionNotificationIncludesProductID` |
| 15 | 服务 | `fetchAllProducts` / `fetchAllSubscriptionGroups` 真实 StoreKit 抓取与分组 | P2 | ❌ 缺失 | - (依赖 StoreKit 运行环境/测试配额) |
| 16 | 服务 | `purchase(_:)` 购买流程、`inspectSubscriptionStatus`、`bootstrap` 交易监听 | P2 | ❌ 缺失 | - (依赖真实交易/沙盒环境) |

### 回归用例

| ID | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|------|----------|
| 17 | 未映射商品不能延长付费权益；覆盖自动/非自动续订及输入顺序 | P0 | ✅ 已覆盖 | `unknownProductsCannotExtendPaidEntitlements` |

> 用例 17 修复前会把已知商品 100 秒的期限扩展为未知商品的 10000 秒；修复后忽略不授予付费等级的商品。

### 新增边界用例

| ID | 描述 | 优先级 | 状态 | 测试方法 |
|----|------|------|------|----------|
| 18 | 三种权益等级的可选到期时间 Codable 往返，nil 不授予权益 | P0 | ✅ 已覆盖 | `purchaseInfoCodablePreservesOptionalExpiration` |
| 19 | 非续订到期时间严格大于 now，覆盖前/等于/后三个边界 | P0 | ✅ 已覆盖 | `nonRenewableExpirationBoundaryIsStrict` |
| 20 | 重复商品 ID、宽限期、重试期与同级首项选择 | P1 | ✅ 已覆盖 | `subscriptionSelectionHandlesDuplicateProductsGraceAndBillingRetry` |
| 21 | 公开缓存读取反映更新和过期，错误类型/缺字段/未知等级回落 | P0 | ✅ 已覆盖 | `cachedAccessorsReflectCurrentDataAndRejectInvalidCache` |

> 24 个测试方法已在 macOS 运行，iOS 未实跑。缓存测试串行运行并恢复原始 UserDefaults 两个键；不调用 StoreKit 购买或联网抓取。统计仅表示清单场景，不是源码覆盖率。

## 覆盖率统计

- P0: 已覆盖 12 / 12
- P1: 已覆盖 6 / 6
- P2: 已覆盖 1 / 3
- **合计: 19 / 21**（15-16 尚未覆盖，可使用 StoreKit Testing / 沙盒验证，无需真实付费）

## 优先级说明

- **P0**: 权益判定、tier 归并、校验与过期回退、最高订阅索引
- **P1**: DTO 拆分/分组、元信息/通知稳定性
- **P2**: 网络抓取与真实购买流程(需 StoreKit 沙盒/测试配额)

## 跨平台说明

- StoreKit 2 在 iOS 17+ / macOS 14+ 可用;visionOS 下 `purchase` 直接返回 nil
- 权益缓存依赖 `UserDefaults`,纯逻辑跨平台一致

## 测试执行

```bash
cd Packages/ProviderStore
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
