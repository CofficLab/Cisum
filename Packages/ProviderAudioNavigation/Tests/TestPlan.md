# TestPlan — ProviderAudioNavigation

## 包概述

ProviderAudioNavigation 提供音频库中的曲目导航能力（上一首/下一首/第一首/最后一首）。

核心组件:
- `AudioTrackNavigationProviding` - 音频导航协议
- 协议扩展：提供不带 verbose 参数的便利方法

## 公开 API

### AudioTrackNavigationProviding (协议)
方法:
- `nextURL(after current: URL?, verbose: Bool) async throws -> URL?` - 获取当前曲目之后的曲目
- `previousURL(before current: URL?, verbose: Bool) async throws -> URL?` - 获取当前曲目之前的曲目
- `firstURL() async throws -> URL?` - 获取音频库中的第一首曲目
- `lastURL() async throws -> URL?` - 获取音频库中的最后一首曲目

### 协议扩展
方法:
- `nextURL(after current: URL?) async throws -> URL?` - 便利方法，verbose 默认为 false
- `previousURL(before current: URL?) async throws -> URL?` - 便利方法，verbose 默认为 false

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|----------|
| 1 | 协议扩展 | 便利方法 nextURL 默认 verbose 为 false | 实现协议的 stub | 调用 `nextURL(after: nil)` | verbose 参数为 false | ✅ 已覆盖 | `navigationConvenienceMethodsDisableVerboseLogging` |
| 2 | 协议扩展 | 便利方法 previousURL 默认 verbose 为 false | 实现协议的 stub | 调用 `previousURL(before: nil)` | verbose 参数为 false | ✅ 已覆盖 | `navigationConvenienceMethodsDisableVerboseLogging` |
| 3 | 协议方法 | nextURL 返回正确的下一首曲目 | 实现协议的 stub | 调用 `nextURL(after: current, verbose: true)` | 返回预期的下一首 URL | ✅ 已覆盖 | `nextURLReturnsCorrectNextTrack` |
| 4 | 协议方法 | previousURL 返回正确的上一首曲目 | 实现协议的 stub | 调用 `previousURL(before: current, verbose: true)` | 返回预期的上一首 URL | ✅ 已覆盖 | `previousURLReturnsCorrectPreviousTrack` |
| 5 | 协议方法 | firstURL 返回第一首曲目 | 实现协议的 stub | 调用 `firstURL()` | 返回音频库第一首 URL | ✅ 已覆盖 | `firstURLReturnsFirstTrack` |
| 6 | 协议方法 | lastURL 返回最后一首曲目 | 实现协议的 stub | 调用 `lastURL()` | 返回音频库最后一首 URL | ✅ 已覆盖 | `lastURLReturnsLastTrack` |
| 7 | 协议方法 | nextURL 可以接受 nil 作为当前曲目 | - | 调用 `nextURL(after: nil)` | 返回第一首或 nil | ✅ 已覆盖 | `nextURLAcceptsNilAsCurrentTrack` |
| 8 | 协议方法 | previousURL 可以接受 nil 作为当前曲目 | - | 调用 `previousURL(before: nil)` | 返回最后一首或 nil | ✅ 已覆盖 | `previousURLAcceptsNilAsCurrentTrack` |
| 9 | 协议方法 | nextURL 可以抛出错误 | 实现抛出错误的 stub | 调用 `nextURL(after: current)` | 抛出预期的错误 | ✅ 已覆盖 | `nextURLCanThrowError` |
| 10 | 协议方法 | previousURL 可以抛出错误 | 实现抛出错误的 stub | 调用 `previousURL(before: current)` | 抛出预期的错误 | ✅ 已覆盖 | `previousURLCanThrowError` |
| 11 | 协议方法 | firstURL 可以抛出错误 | 实现抛出错误的 stub | 调用 `firstURL()` | 抛出预期的错误 | ✅ 已覆盖 | `firstURLCanThrowError` |
| 12 | 协议方法 | lastURL 可以抛出错误 | 实现抛出错误的 stub | 调用 `lastURL()` | 抛出预期的错误 | ✅ 已覆盖 | `lastURLCanThrowError` |
| 13 | 协议方法 | verbose 参数正确传递 | 实现协议的 stub | 调用带 verbose 参数的方法 | stub 记录到正确的 verbose 值 | ✅ 已覆盖 | `verboseParameterIsPassedCorrectly` |

## 覆盖率统计

- P0 (核心功能): 6/6 ✅
- P1 (边界情况): 5/5 ✅
- P2 (错误处理): 2/2 ✅

**总计: 13/13 (100%)**

## 优先级说明

- **P0**: 核心功能，必须覆盖（协议方法、便利方法）
- **P1**: 边界情况，建议覆盖（nil 参数、verbose 传递）
- **P2**: 错误处理，可选覆盖（抛出错误场景）

## 跨平台说明

- 所有功能在 iOS 和 macOS 上行为一致
- 协议标记为 @MainActor，确保主线程安全

## 测试执行

```bash
cd Packages/ProviderAudioNavigation
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
