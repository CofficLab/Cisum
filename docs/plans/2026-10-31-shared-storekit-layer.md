# 三项目共用购买能力 — 分层设计

> 结论：Cisum / Netto / JuiceNote 三个 App 共用商店（StoreKit 2）能力，
> 按 Coffic Lab 家族的分层纪律拆成三层。

## 分层

| 层 | 位置 | 职责 | 依赖 |
|---|---|---|---|
| 通用契约 | `LumiProviders/ProviderStore` | 订阅档位、权益快照、权益能力协议、购买呈现协议、商品表契约 | 仅 Foundation |
| 通用机制 | `LumiStoreKit/KitStoreKit` | 交易监听、权益校准、商品拉取、购买、恢复、交易验证、订阅聚合 | StoreKit + LumiLoggingKit |
| App 商品表 | 各项目的 `ProviderStoreKit` 或 `PluginStore` | 商品 ID → 档位映射 | 通用契约 |
| App 功能 | 各项目的 `PluginStore` | 权益能力实现、购买面板、设置入口 | 通用契约 + 通用机制 + 商品表 |

### 依赖方向

```
App PluginStore ──> ProviderStore（契约）
                 ──> KitStoreKit（机制）
                 ──> App 商品表

KitStoreKit ──> 无（零 Provider 依赖）
App 商品表 ──> ProviderStore（契约）
```

依赖方向单一：**Provider → Kit**。Kit 层不认识「档位」，契约层不碰 StoreKit。

### 为什么 Kit 层不认识档位

档位（Pro / Ultimate）是**产品语义**：不同 App 的档位命名与含义不同，
而「哪些订阅商品在有效期内、最晚到什么时候」是**机制**：各 App 完全一致。

Kit 层因此只回答机制问题，把「商品 ID → 档位」的映射留给各 App：

- Kit 层零 Provider 依赖，不会反向污染契约层；
- 各 App 的商品体系不被共享层污染（商品 ID 是 App Store 后台的真实配置）。

## 各项目接入情况

| 项目 | 商品表 | 功能包 | 说明 |
|---|---|---|---|
| Cisum | `Packages/ProviderStoreKit`（`CisumStoreCatalog`） | `Packages/PluginStore` | 原 `ProviderStore` 包改名为 `ProviderStoreKit`——共享契约的模块名是 `ProviderStore`，同名模块在同一 target 图里无法链接 |
| Netto | `Packages/PluginStore`（`NettoStoreCatalog`） | `Packages/PluginStore` | 原 `ProviderStore` 包整体删除；Netto 特有的 `StoreProviding` 能力契约迁入新建的 `Packages/ProviderStoreKit` |
| JuiceNote | `Packages/ProviderStoreKit`（`JuiceNoteStoreCatalog`） | `Packages/PluginStore` | 新架构下原本没有商店能力（旧实现只在 `legacy/` 中），本次新建 |

### 商品表为什么不能共享

商品 ID 是各 App 在 App Store 后台的真实配置：

- **Cisum**：`com.yueyi.cisum.*`（另含 `com.yueyi.kuaiyizhi.*` 历史 ID）
- **Netto**：`com.coffic.netto.*`
- **JuiceNote**：`com.yueyi.kuaiyizhi.*`

JuiceNote 的 `com.yueyi.kuaiyizhi.*` 是已上线商品的真实 ID，改名等于让已购用户
丢失权益——因此 Cisum 侧也保留了这批历史 ID 映射。

共享层**不含任何 App 专属商品 ID**，商品表由各 App 注入。

## 已知差异与处理

| 差异点 | Cisum | Netto | JuiceNote | 处理 |
|---|---|---|---|---|
| 非续订订阅有效期 | 用 `expirationDate` | 用 `purchaseDate + 1年` | 同 Netto | 共享层统一：优先 `expirationDate`，缺失时回退 `purchaseDate + 1年` |
| 已购归类魔法串 | 无 | `"nonRenewing.standard"` | legacy 同 Netto | 各 App 保留在本地（属展示型逻辑），未上移 |
| 错误文案 | 英文 | 中文 | — | 各 App 保留本地文案 |
| 恢复购买 | `AppStore.sync()` | 重放校准 | `AppStore.sync()` | Netto 无有效会话时 `sync()` 会抛错，故只重放校准；两者读取同一份 `currentEntitlements`，效果等价 |
| 监听启动 | `bootstrap()`（全局静态） | 插件持有 Task | 插件持有 Task | 共享层提供幂等启动 + 显式停止 |

## 权益判定的单一真值

`StoreEntitlementProviding.entitlement`（快照）是唯一真值，`tier` 由它派生。

反过来做（档位为准、快照派生）会产出自相矛盾的快照：档位是 `.pro` 却因为
「没有到期时间」而被判为已过期。过期判定才是权益的真正闸门，所以它必须是真值。

## 测试分布

| 范围 | 位置 |
|---|---|
| 通用机制（订阅聚合、交易验证、权益过期） | `LumiStoreKit/Tests` |
| 通用契约（档位、快照、能力协议） | `LumiProviders/Tests/ProviderStoreTests` |
| 各 App 的商品表映射、展示模型、UI 判定 | 各项目自己的包测试 |

通用机制不在各 App 重复测试——三份实现会各自漂移，而共享层只有一份。

## 发布

- `LumiProviders`：`1.15.0`（商品表推导）、`1.16.0`（档位默认显示名）、`1.17.0`（`isNotProOrHigher`）
- `LumiStoreKit`：`1.0.1`

三项目通过 URL 引用这两个包，`from:` 版本约束已相应更新。
