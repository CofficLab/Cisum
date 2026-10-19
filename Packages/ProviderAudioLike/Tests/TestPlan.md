# TestPlan — ProviderAudioLike

## 包概述

ProviderAudioLike 提供音频收藏能力的 DTO 和协议定义。不包含具体实现（由 PluginAudioLike 负责）。

核心组件:
- `AudioLikeItem` - 跨插件传递的喜欢条目数据结构
- `AudioLikeProviding` - 音频喜欢能力协议

## 公开 API

### AudioLikeItem (结构体)
属性:
- `audioId: String` - 音频 ID
- `url: URL?` - 音频 URL（可选）
- `title: String?` - 音频标题（可选）
- `liked: Bool` - 是否已喜欢
- `id: String` - 计算属性，返回 audioId

协议:
- `Identifiable` - 提供 id 属性
- `Sendable` - 可跨 actor 传递
- `Equatable` - 支持相等比较

初始化器:
- `init(audioId: String, url: URL?, title: String?, liked: Bool)`

### AudioLikeProviding (协议)
方法:
- `isLiked(url: URL) async -> Bool` - 检查指定 URL 是否已喜欢
- `allLiked() async -> [AudioLikeItem]` - 获取所有已喜欢的音频
- `updateLikeStatus(audioId: String, liked: Bool, url: URL?, title: String?) async throws` - 更新收藏状态

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|----------|
| 1 | 数据结构 | AudioLikeItem 的 id 返回 audioId | - | 创建 item 并访问 id | 返回 audioId | ✅ 已覆盖 | `audioLikeItemExposesStableTransportIdentity` |
| 2 | 数据结构 | AudioLikeItem 的 liked 属性正确 | - | 创建 item 并访问 liked | 返回传入的 liked 值 | ✅ 已覆盖 | `audioLikeItemExposesStableTransportIdentity` |
| 3 | 数据结构 | AudioLikeItem 初始化器正确设置所有属性 | - | 创建 item 并检查所有属性 | 所有属性正确设置 | ✅ 已覆盖 | `audioLikeItemInitializerSetsAllProperties` |
| 4 | 数据结构 | AudioLikeItem 支持可选的 url | - | 创建 url 为 nil 的 item | url 为 nil | ✅ 已覆盖 | `audioLikeItemSupportsOptionalURL` |
| 5 | 数据结构 | AudioLikeItem 支持可选的 title | - | 创建 title 为 nil 的 item | title 为 nil | ✅ 已覆盖 | `audioLikeItemSupportsOptionalTitle` |
| 5b | 数据结构 | AudioLikeItem 支持 url 与 title 同时为 nil | - | 创建两个可选值均为 nil 的 item | url 与 title 均为 nil，audioId / liked 仍正确 | ✅ 已覆盖 | `audioLikeItemSupportsBothOptionalsAsNil` |
| 6 | 数据结构 | AudioLikeItem 的 Equatable 实现 | - | 比较两个相同和不同的 item | 相等比较正确 | ✅ 已覆盖 | `audioLikeItemEquatableWhenEqual`, `audioLikeItemEquatableWhenAudioIdDiffers`, `audioLikeItemEquatableWhenLikedDiffers`, `audioLikeItemEquatableWhenURLDiffers`, `audioLikeItemEquatableWhenTitleDiffers` |
| 7 | 数据结构 | AudioLikeItem 的 Sendable 特性 | - | 在不同 actor 间传递 item | 无编译警告 | ✅ 已覆盖 | `audioLikeItemIsSendable` |
| 8 | 协议 | AudioLikeProviding 协议方法签名 | - | 检查协议定义 | 方法签名正确 | ✅ 已覆盖 | `audioLikeProvidingProtocolMethodsExist` |

## 覆盖率统计

- P0 (核心功能): 3/3 ✅
- P1 (边界情况): 5/5 ✅
- P2 (集成场景): 1/1 ✅

**总计: 9/9 (100%)**

## 优先级说明

- **P0**: 核心功能，必须覆盖（数据结构基本属性、协议定义）
- **P1**: 边界情况，建议覆盖（可选值、相等比较）
- **P2**: 集成场景，可选覆盖（协议方法签名验证）

## 跨平台说明

- 所有功能在 iOS 和 macOS 上行为一致
- 纯数据结构，无平台特定代码

## 测试执行

```bash
cd Packages/ProviderAudioLike
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
