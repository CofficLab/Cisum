# TestPlan — PluginStore

## 包概述

商店插件：版本检查、更新提示与购买流程。

公开类型:
- `StorePlugin`
- `StoreSetting`

### README 中的测试说明（摘自 `README.md`）

- **Test files:**
  - `Tests/StorePluginTests.swift`.
- **Key scenarios tested:**
  - Metadata: `StorePluginInfo.titleKey = "Store"`, `iconName = "cart"`, `SubscriptionTier.none.isFreeVersion`.
  - Pro product-ID aliases map to `.pro` and are included in `StoreConfig.allProductIds`.
  - Highest active subscription index selects an active subscribed subscription and ignores expired ones.
  - Product-list state machine: loading/error/empty/content transitions; only the latest load result is applied; singular vs plural count text.
  - Purchase-info generation guard; readable labels for purchase/restore/close buttons; `StoreError` user-facing descriptions; transaction listener starts only once.
  - `StoreService.postTransactionUpdated` posts `.storeTransactionUpdated` with the product ID.
  - Plugin assembles/reuses the view model; `StoreObserver.cancel()` is idempotent; view model starts in the free presentation state.
- **Running tests:**
  ```bash
  cd /Users/angel/Code/Coffic/Cisum/Packages/PluginStore
  swift test
  ```
- Tests focus on the pure StoreKit-adjacent policies (tier mapping, state machines, generation guards, labels); real App Store transactions are not executed.

## 测试用例清单

下表由 `Tests/` 下的真实 `@Test` 声明自动生成，方法名与代码一一对应。

| ID | 类别 | 描述 | 优先级 | 状态 | 测试文件 | 测试方法 |
|----|------|------|--------|------|----------|----------|
| 1 | 元数据 | Store info exports metadata | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `storeInfoExportsMetadata` |
| 2 | 行为 | Cisum subscription product aliases grant pro tier | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `cisumSubscriptionProductAliasesGrantProTier` |
| 3 | 行为 | Active subscribed status selects current subscription | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `activeSubscribedStatusSelectsCurrentSubscription` |
| 4 | 行为 | Expired subscription status is ignored | P1 | ✅ 已覆盖 | `StorePluginTests.swift` | `expiredSubscriptionStatusIsIgnored` |
| 5 | 状态 | Product list shows loading error empty and content states | P1 | ✅ 已覆盖 | `StorePluginTests.swift` | `productListShowsLoadingErrorEmptyAndContentStates` |
| 6 | 行为 | Product list only applies latest load result | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `productListOnlyAppliesLatestLoadResult` |
| 7 | 行为 | Product list uses singular subscription count only for one option | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `productListUsesSingularSubscriptionCountOnlyForOneOption` |
| 8 | 存储 | Store setting only applies latest purchase info result | P1 | ✅ 已覆盖 | `StorePluginTests.swift` | `storeSettingOnlyAppliesLatestPurchaseInfoResult` |
| 9 | 存储 | Store setting icon buttons expose readable labels | P1 | ✅ 已覆盖 | `StorePluginTests.swift` | `storeSettingIconButtonsExposeReadableLabels` |
| 10 | 存储 | Store sheet close button exposes readable label | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `storeSheetCloseButtonExposesReadableLabel` |
| 11 | 存储 | Store errors use user readable descriptions | P1 | ✅ 已覆盖 | `StorePluginTests.swift` | `storeErrorsUseUserReadableDescriptions` |
| 12 | 行为 | Transaction listener starts only once | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `transactionListenerStartsOnlyOnce` |
| 13 | 存储 | Purchase update posts store transaction notification | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `purchaseUpdatePostsStoreTransactionNotification` |
| 14 | 插件 | Store plugin assembles and tears down state | P0 | ✅ 已覆盖 | `StorePluginTests.swift` | `storePluginAssemblesAndTearsDownState` |
| 15 | 观察者 | Store observer cancels tokens idempotently | P1 | ✅ 已覆盖 | `StorePluginTests.swift` | `storeObserverCancelsTokensIdempotently` |
| 16 | 视图模型 | Store view model starts with free presentation | P2 | ✅ 已覆盖 | `StorePluginTests.swift` | `storeViewModelStartsWithFreePresentation` |

## 覆盖率统计

- P0: 9 / 9 ✅
- P1: 6 / 6 ✅
- P2: 1 / 1 ✅

**总计: 16 / 16**（本包 `Tests/` 中已声明的 `@Test` 全部登记）

## 测试文件

- `StorePluginTests.swift` — 16 条用例

## 优先级说明

- **P0**: 主路径行为（状态推导、事件翻译、核心策略判定）
- **P1**: 边界与退化（Provider 缺失、取消、失效、并发、竞态）
- **P2**: 视图 / 布局 / 系统集成相关，依赖真实窗口或系统环境

## 跨平台说明

- 测试以 `swift test`（macOS 主机）运行为基准
- 平台判定通过注入 `isMacOS` 一类参数在单测内同时覆盖 iOS / macOS 两条分支
- 视图层端到端行为需在 iOS 模拟器或真机验证，不在单测清单内

## 测试执行

```bash
cd Packages/PluginStore
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例,再写实现
2. **Bug 修复** → 追加回归用例,标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan,标记 ✅ 并填写测试方法名
