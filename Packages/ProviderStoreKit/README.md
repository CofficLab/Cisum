# ProviderStoreKit

Cisum 的商店适配层：把共享的商店契约与 StoreKit 机制，接到 Cisum 自己的商品表与展示模型上。

## 分层

| 层 | 位置 | 职责 |
|---|---|---|
| 契约 | `ProviderStore`（[LumiProviders](https://github.com/CofficLab/LumiProviders)） | 订阅档位、权益快照、权益能力协议、购买呈现协议、商品表契约 |
| 机制 | `KitStoreKit`（[LumiStoreKit](https://github.com/CofficLab/LumiStoreKit)） | 交易监听、权益校准、商品拉取、购买、恢复、交易验证、订阅聚合 |
| 适配 | 本包 | Cisum 商品表、展示模型（DTO）、订阅组状态查询、档位文案 |

共享层负责**机制**与**契约**；本包负责 **Cisum 的产品语义**——哪个商品对应什么档位、购买面板长什么样。

## 为什么单独成包

本地包原本叫 `ProviderStore`，与共享契约层的 `ProviderStore` **模块重名**。同一 target 图里出现两个同名模块会导致编译失败，因此本包改名为 `ProviderStoreKit`，并只保留 Cisum 独有的内容（商品表、DTO、订阅组查询）。

## 商品表

`CisumStoreCatalog` 是「商品 ID → 订阅档位」的唯一真值源。商品 ID 集合历史上散落在代码、`.storekit` 配置与商品清单文件三处，各自漂移；漂移的后果不是「配置不好看」，而是**付费链路静默断裂**：

- 商品在 `.storekit` 里但不在表里 → 查档位得到 `.none` → 权益判定跳过 → **用户付了钱，权益没到账**；
- 商品在表里但线上没有 → 商品拉取失败 → 购买面板加载不出来。

`scripts/sync-storekit-config.py` 用测试守住这份表与 `.storekit` 配置的一致性。

## 内容

- **DTO**（`DTO/`）：`ProductDTO`、`ProductGroupsDTO`、`SubscriptionInfoDTO`、`SubscriptionGroupDTO`、`StoreSubscriptionStatusDTO`、`IntroductoryOfferDTO`、`StoreSubscriptionPeriodDTO` —— StoreKit 类型的值化镜像，供 Cisum 的商店 UI 使用。
- **商品表**（`Models/StoreConfig.swift`）：`CisumStoreCatalog`，实现共享契约 `StoreProductCatalog`。
- **权益缓存**（`Models/StoreState.swift`）：权益快照的 `UserDefaults` 持久化与档位显示文案。
- **服务**（`Services/StoreService.swift`）：把共享机制层的结论翻译成 Cisum 的档位语义；保留 Cisum 独有的订阅组状态查询。
- **事件**（`Models/StoreEvents.swift`）：`.storeTransactionUpdated` / `.Restored` 通知与 SwiftUI 辅助修饰符。

## 测试

```bash
cd Packages/ProviderStoreKit
swift test
```

通用机制（交易监听、权益校准、订阅聚合、交易验证）由共享的 `KitStoreKit` 承担并单独测试，本包不重复覆盖。
