# 插件包目录结构规范

> 本规范定义了 Cisum 项目中 `Packages/` 下所有 SPM 插件包的内部目录结构标准。
> 基于项目中 50+ 插件包的实际分析，提炼出统一的最佳实践。

---

## 1. SPM Package 目录结构

### 1.1 包级目录

每个 SPM Package 的根目录必须包含以下结构：

```
Packages/<PackageName>/
├── Package.swift              # 必需
├── README.md                  # 必需
├── Resources/                 # 可选，需要本地化或媒体资源时创建
│   └── *.xcstrings
├── Sources/
│   └── <PackageName>/         # 必需，包裹目录（与包名一致）
│       └── ...                # 源码文件与子目录
└── Tests/
    └── <PackageName>Tests/    # 必需，测试包裹目录
        └── ...                # 测试文件
```

### 1.2 必需项

| 项目 | 必需 | 说明 |
|------|:----:|------|
| `Package.swift` | ✅ | SPM 包声明文件 |
| `README.md` | ✅ | 包功能说明 |
| `Sources/<PackageName>/` | ✅ | 源码包裹目录，名称与包名一致 |
| `Tests/<PackageName>Tests/` | ✅ | 测试包裹目录，名称为包名 + Tests |
| `Resources/` | ⬚ | 仅当需要 `.xcstrings` 或媒体资源时创建 |

### 1.3 命名规范

| 范畴 | 规范 | 示例 |
|------|------|------|
| 插件包名 | `Plugin<Feature>` | `PluginAudio`、`PluginStorage` |
| 工具包名 | `Kit<Feature>` | `KitAppEvents`、`KitEventObservation` |
| 提供者包名 | `Provider<Feature>` | `ProviderPlayback`、`ProviderStorage` |
| 工厂包名 | `Factory<App>` | `FactoryCisum` |
| 测试目录 | `<PackageName>Tests` | `PluginAudioTests` |

---

## 2. Sources 内部代码组织

### 2.1 核心规则：包裹目录

`Sources/` 下**必须**使用与包名一致的子目录作为命名空间，所有源码文件放入该目录中。

```
Sources/
  PluginStorage/                 ← ✅ 包裹目录
    StoragePlugin.swift
    Views/

Sources/
  StoragePlugin.swift            ← ❌ 禁止：缺少包裹目录，需迁移
```

> **注意**：部分早期插件包（如 `PluginStorage`）的源码直接放在 `Sources/` 下而无包裹目录。新包或重构时应统一迁移为包裹目录结构。

### 2.2 Plugin 类包分层

#### 简单插件（≤ 3 个源文件）

```
Sources/
  PluginOpenButton/
    OpenButtonPlugin.swift
    Support/
      PluginLocalization.swift
```

#### 标准插件（4 ~ 10 个源文件）

```
Sources/
  PluginStorage/
    StoragePlugin.swift          # 入口
    StoragePluginInfo.swift      # 插件信息
    Models/                      # 数据模型
    Observers/                   # 事件订阅
    Providers/                   # 协议实现
    ViewModels/                  # 视图模型
    Views/                       # SwiftUI 视图
```

#### 复杂插件（> 10 个源文件）

```
Sources/
  PluginAudio/
    AudioPlugin.swift
    Models/
    Observers/
    Providers/
    Services/
    Support/
    ViewModels/
    Views/
      Player/                    # 按功能分组
      Library/
      Settings/
```

### 2.3 目录职责说明

| 目录 | 职责 | 存放内容 |
|------|------|---------|
| `Models/` | 数据模型 | struct / class / enum 数据定义 |
| `Observers/` | 事件订阅 | `*Observer` 等监听类型 |
| `Capabilities/` | 消费外部能力 | `<前缀><Domain>Capability` 窄协议 + Adapter，详见 [Capabilities 规范](./plugin-capabilities.md) |
| `Support/` | 辅助 | `PluginLocalization.swift`、轻量扩展 |
| `ViewModels/` | 视图模型 | `@Observable` / `ObservableObject` 类 |
| `Views/` | 视图 | SwiftUI `View` 组件 |
| `Providers/` | 协议实现 | `*Providing` 协议的具体实现 |
| `Services/` | 业务服务 | 复杂业务逻辑（播放引擎等） |
| `Helpers/` | 辅助函数 | 比 Support 更轻量的工具代码 |

### 2.4 Kit / 框架类包分层

```
Sources/
  KitAppEvents/
    Contracts/                   # 公共协议
    Core/                        # 核心实现
    Support/                     # 辅助代码
```

### 2.5 Provider 类包分层

Provider 包通常结构最简：

```
Sources/
  ProviderPlayback/
    PlaybackProviding.swift
    DefaultPlaybackProvider.swift
```

---

## 3. Views 二级分组规则

当 `Views/` 目录下文件 **超过 5 个** 时，应按功能模块拆分子目录：

```
Views/
  Player/
    PlayerView.swift
    PlayerControlsView.swift
  Library/
    LibraryView.swift
    LibraryItemView.swift
```

**判断标准**：
- ≤ 5 个视图文件 → 平铺在 `Views/` 下
- \> 5 个视图文件 → 按功能分组为子目录
- 每个子目录至少 2 个文件

---

## 4. Tests 组织规范

### 4.1 目录结构

所有测试使用包裹目录，放在 `Tests/<PackageName>Tests/` 下：

```
Tests/
  PluginAudioTests/              ← ✅ 包裹目录
    AudioPluginTests.swift
    AudioViewModelTests.swift

Tests/
  SomeTests.swift                ← ❌ 禁止：缺少包裹目录
```

### 4.2 文件命名

| 项 | 规范 | 示例 |
|----|------|------|
| 测试目录 | `<PackageName>Tests` | `PluginAudioTests` |
| 测试文件 | `<SourceFileName>Tests.swift` | `AudioViewModelTests.swift` |

### 4.3 测试框架

新代码优先使用 **Swift Testing**（`import Testing`）：

```swift
import Testing
@testable import PluginStorage

@Suite("StoragePlugin")
struct StoragePluginTests {
    @Test("initializes storage provider")
    func initializesProvider() {
        // ...
    }
}
```

遗留的 **XCTest** 可保留，不强制迁移。

---

## 5. Package.swift 配置

### 5.1 测试 target

```swift
.testTarget(
    name: "PluginStorageTests",
    dependencies: ["PluginStorage"]
)
```

### 5.2 资源配置

需要本地化资源时：

```swift
.target(
    name: "PluginStorage",
    dependencies: [...],
    resources: [.process("Resources")]
)
```

不需要资源时省略 `resources` 参数，且 **不要** 创建空的 `Resources/` 目录。

---

## 6. 最佳实践

### ✅ 推荐

- 只有 2 ~ 3 个文件时，直接放包裹目录下
- 文件名与主类型名一致
- 每个视图单独一个文件
- 目录嵌套不超过 3 层
- 新插件包统一使用包裹目录结构

### ❌ 避免

- 无脑为每个目录分类都创建子目录
- 创建空的占位目录
- 在包裹目录外直接放源码文件

---

## 7. 实际参考

| 包 | 复杂度 | 分层方式 |
|----|--------|---------|
| `PluginAudio` | 复杂 | Models / Observers / Providers / Services / ViewModels / Views |
| `PluginStorage` | 标准 | FileInfo / Migrate / Observers / Providers / ViewModels / Views |
| `KitAppEvents` | 框架 | 按架构分层 |
| `ProviderPlayback` | 简单 | 平铺在包裹目录下 |

---

## 相关规范

- [插件国际化规范](./plugin-i18n-rules.md) — xcstrings 文件管理
- [日志记录规范](./swift-log.md) — Swift 日志记录标准
