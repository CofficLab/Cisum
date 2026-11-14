# 插件国际化（i18n）规范

> 本规范定义了 Cisum 项目中所有插件的多语言（国际化）实现方式和最佳实践。
> 每个插件作为独立的 Swift Package，在 `Packages/` 目录下管理自己的国际化资源。

---

## 核心原则

**每个插件独立管理国际化资源，使用统一的 `.xcstrings` 格式，通过 SPM 的 `bundle: .module` 机制加载，支持动态多语言切换。**

所有用户可见的文本都必须进行国际化，禁止在代码中硬编码用户可见字符串。

---

## 项目结构

插件已从旧的 `CisumApp/Plugins/` 迁移为 SPM 标准目录结构：

```
Packages/
├── AudioPlayModePlugin/
│   ├── Package.swift
│   ├── Sources/
│   │   └── AudioPlayModePlugin/
│   │       ├── AudioPlayModeRootView.swift
│   │       ├── AudioPlayModePluginInfo.swift
│   │       └── Resources/
│   │           └── Audio-PlayMode.xcstrings    ← 国际化文件在这里
│   └── Tests/
│       └── AudioPlayModePluginTests/
├── AudioDownloadPlugin/
│   ├── Package.swift
│   ├── Sources/
│   │   └── AudioDownloadPlugin/
│   │       ├── ...
│   │       └── Resources/
│   │           └── Audio-Download.xcstrings
├── ThemeCisumPlugin/
│   ├── ...
│   └── Sources/ThemeCisumPlugin/Resources/Theme-Cisum.xcstrings
└── ...
```

---

## Package.swift 配置

每个需要国际化的插件，其 `Package.swift` 必须包含以下配置：

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioPlayModePlugin",
    defaultLocalization: "en",                    // ← 必须：设置默认本地化语言
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AudioPlayModePlugin",
            targets: ["AudioPlayModePlugin"]
        )
    ],
    dependencies: [
        // ...
    ],
    targets: [
        .target(
            name: "AudioPlayModePlugin",
            dependencies: [
                // ...
            ],
            path: "Sources/AudioPlayModePlugin",
            resources: [
                .process("Resources")              // ← 必须：包含 Resources 目录
            ]
        ),
        .testTarget(
            name: "AudioPlayModePluginTests",
            dependencies: ["AudioPlayModePlugin"],
            path: "Tests/AudioPlayModePluginTests"
        )
    ]
)
```

**关键配置项：**
- `defaultLocalization: "en"` — 声明默认本地化语言
- `resources: [.process("Resources")]` — 将 Resources 目录下的文件作为资源打包，SPM 会自动处理 `.xcstrings` 文件

---

## 文件格式

### 文件扩展名

```
<Table-Name>.xcstrings
```

### 文件结构

```json
{
  "sourceLanguage": "en",
  "strings": {
    "Audio Play Mode": {
      "localizations": {
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "音频播放模式"
          }
        },
        "zh-HK": {
          "stringUnit": {
            "state": "translated",
            "value": "音頻播放模式"
          }
        }
      }
    }
  },
  "version": "1.0"
}
```

> **注意**：源语言 `en` 的翻译条目可以省略（即不需要在 `localizations` 中显式列出 `en`），因为 key 本身就是英文值。

### 字段说明

| 字段 | 说明 | 必填 | 示例 |
|------|------|------|------|
| `sourceLanguage` | 源语言代码 | ✅ | `"en"` |
| `version` | 文件格式版本 | ✅ | `"1.0"` |
| `strings` | 字符串字典 | ✅ | - |
| `localizations` | 语言列表 | ✅ | - |
| `state` | 翻译状态 | ✅ | `"translated"` |
| `value` | 翻译后的文本 | ✅ | `"音频播放模式"` |

### 翻译状态

| 状态 | 说明 |
|------|------|
| `translated` | 已完成翻译 |
| `needsReview` | 需要审查 |
| `notTranslated` | 未翻译 |

---

## 支持语言

| 语言代码 | 语言 | 优先级 |
|---------|------|--------|
| `en` | 英语 | 必须（源语言） |
| `zh-Hans` | 简体中文 | 必须 |
| `zh-HK` | 繁体中文 | 推荐 |

---

## 文件命名

### 命名规则

使用 `<类别>-<功能>.xcstrings` 格式，以连字符分隔：

```
<类别>-<功能>.xcstrings
```

或对于主插件，直接使用类别名：

```
<类别>.xcstrings
```

### 命名示例

| 插件包名 | xcstrings 文件名 | table 参数 |
|---------|-----------------|-----------|
| `AudioPlugin` | `Audio.xcstrings` | `"Audio"` |
| `AudioPlayModePlugin` | `Audio-PlayMode.xcstrings` | `"Audio-PlayMode"` |
| `AudioDownloadPlugin` | `Audio-Download.xcstrings` | `"Audio-Download"` |
| `BookSettingsPlugin` | `Book-Settings.xcstrings` | `"Book-Settings"` |
| `ThemeCisumPlugin` | `Theme-Cisum.xcstrings` | `"Theme-Cisum"` |
| `WelcomePlugin` | `Welcome.xcstrings` | `"Welcome"` |
| `StoragePlugin` | `Storage.xcstrings` | `"Storage"` |

### 文件位置

```
Packages/<PluginPackageName>/Sources/<TargetName>/Resources/<TableName>.xcstrings
```

**完整示例**：
```
Packages/AudioPlayModePlugin/Sources/AudioPlayModePlugin/Resources/Audio-PlayMode.xcstrings
Packages/BookSettingsPlugin/Sources/BookSettingsPlugin/Resources/Book-Settings.xcstrings
Packages/ThemeCisumPlugin/Sources/ThemeCisumPlugin/Resources/Theme-Cisum.xcstrings
```

---

## 使用方式

### ⚠️ 关键：必须传入 `bundle: .module`

由于插件是 SPM Package，**所有** `String(localized:)` 和 `Text()` 调用都必须传入 `bundle: .module`，否则运行时找不到翻译资源。

### 基础用法

```swift
// ✅ 正确：传入 bundle: .module
Text(String(localized: "Hello World", table: "Audio-PlayMode", bundle: .module))

// ❌ 错误：缺少 bundle: .module，运行时会 fallback 到 key
Text(String(localized: "Hello World", table: "Audio-PlayMode"))
```

### 属性定义

```swift
public static let title = String(localized: "Audio Play Mode", table: "Audio-PlayMode", bundle: .module)
public static let description = String(localized: "Audio play mode management", table: "Audio-PlayMode", bundle: .module)
```

### 动态消息（带参数）

```swift
let message = String(localized: "Current branch: %@", table: "Audio-PlayMode", bundle: .module, arguments: branchName)
```

### 完整示例

```swift
import SwiftUI

struct AudioPlayModePluginInfo {
    public static let title = String(localized: "Audio Play Mode", table: "Audio-PlayMode", bundle: .module)
    public static let description = String(localized: "Audio play mode management", table: "Audio-PlayMode", bundle: .module)
}

struct AudioPlayModeRootView: View {
    var body: some View {
        VStack {
            Text(String(localized: "Repeat One", table: "Audio-PlayMode", bundle: .module))
            
            Button {
                alert_info(String(localized: "Shuffle", table: "Audio-PlayMode", bundle: .module))
            } label: {
                Text(String(localized: "Shuffle Play", table: "Audio-PlayMode", bundle: .module))
            }
        }
    }
}
```

### 带参数的字符串

**xcstrings 文件**：
```json
{
  "Selected: %@": {
    "localizations": {
      "zh-Hans": {
        "stringUnit": {
          "state": "translated",
          "value": "已选：%@"
        }
      },
      "zh-HK": {
        "stringUnit": {
          "state": "translated",
          "value": "已選：%@"
        }
      }
    }
  },
  "%lld files": {
    "localizations": {
      "zh-Hans": {
        "stringUnit": {
          "state": "translated",
          "value": "%lld 个文件"
        }
      },
      "zh-HK": {
        "stringUnit": {
          "state": "translated",
          "value": "%lld 個檔案"
        }
      }
    }
  }
}
```

**Swift 代码**：
```swift
Text(String(localized: "Selected: %@", table: "Audio-PlayMode", bundle: .module, arguments: selectedCount))
Text(String(localized: "%lld files", table: "Audio-PlayMode", bundle: .module, arguments: fileCount))
```

### 带命名参数的字符串

**xcstrings 文件**：
```json
{
  "Auto-push \(status): \(project.title)/\(branch.name)": {
    "localizations": {
      "zh-Hans": {
        "stringUnit": {
          "state": "translated",
          "value": "自动推送 %@：%@/%@"
        }
      },
      "zh-HK": {
        "stringUnit": {
          "state": "translated",
          "value": "自動推送 %@：%@/%@"
        }
      }
    }
  }
}
```

**Swift 代码**：
```swift
let message = String(
    localized: "Auto-push \(status): \(project.title)/\(branch.name)",
    table: "Audio-Download",
    bundle: .module
)
```

---

## 创建 xcstrings 文件

### 步骤 1：配置 Package.swift

确保 `Package.swift` 包含 `defaultLocalization: "en"` 和 `resources: [.process("Resources")]`。

### 步骤 2：创建 Resources 目录和文件

```
Packages/<PluginName>/Sources/<TargetName>/Resources/<TableName>.xcstrings
```

### 步骤 3：添加基础结构

```json
{
  "sourceLanguage": "en",
  "strings": {},
  "version": "1.0"
}
```

### 步骤 4：添加字符串并翻译

手动添加或使用 Xcode 的本地化导出功能，为每种支持的语言添加翻译。

### 步骤 5：在代码中使用

```swift
String(localized: "Your Key", table: "<TableName>", bundle: .module)
```

---

## 最佳实践

### ✅ 推荐

1. **所有用户可见文本都国际化**
   - 按钮标题、标签、提示信息
   - 错误消息、成功提示
   - 菜单项、工具提示

2. **使用有意义的键**

   ```swift
   // ✅ 好：使用完整句子作为键
   String(localized: "Confirm Delete Branch", table: "Book-Control", bundle: .module)
   
   // ❌ 避免：使用无意义的键
   String(localized: "btn_confirm_1", table: "Book-Control", bundle: .module)
   ```

3. **始终传入 `bundle: .module`**
   - SPM Package 的资源通过 `.module` bundle 加载
   - 遗漏会导致运行时找不到翻译

4. **保持翻译文件同步**
   - 添加新字符串时同时提供所有语言的翻译
   - 定期审查 `needsReview` 状态的字符串

5. **使用 Xcode 本地化编辑器**
   - 在 Xcode 中打开 `.xcstrings` 文件
   - 使用可视化编辑器管理翻译

6. **注释复杂字符串**

   ```json
   {
     "Auto-push \(status): \(project)/\(branch)": {
       "comment": "status = enabled/disabled, project = project name, branch = branch name",
       "localizations": { ... }
     }
   }
   ```

### ❌ 避免

1. **硬编码用户可见文本**

   ```swift
   // ❌ 错误
   Text("Click here to push")
   
   // ✅ 正确
   Text(String(localized: "Click to push", table: "Audio-Download", bundle: .module))
   ```

2. **遗漏 `bundle: .module`**

   ```swift
   // ❌ 错误：SPM Package 中不传 bundle 会导致翻译不生效
   String(localized: "Hello", table: "Audio-PlayMode")
   
   // ✅ 正确
   String(localized: "Hello", table: "Audio-PlayMode", bundle: .module)
   ```

3. **混合语言**

   ```swift
   // ❌ 错误：中文作为键
   String(localized: "点击推送", table: "Audio-Download", bundle: .module)
   
   // ✅ 正确：使用英文键
   String(localized: "Click to push", table: "Audio-Download", bundle: .module)
   ```

4. **过长的字符串**
   - 将长文本拆分为多个可重用的片段

5. **忽略占位符顺序**
   - 不同语言的语法顺序可能不同，使用命名参数

---

## 检查清单

创建新插件时，确保：

- [ ] `Package.swift` 中设置 `defaultLocalization: "en"`
- [ ] `Package.swift` 中 target 的 `resources` 包含 `.process("Resources")`
- [ ] 创建 `Sources/<TargetName>/Resources/<TableName>.xcstrings` 文件
- [ ] 设置 `sourceLanguage` 为 `"en"`
- [ ] 提供简体中文 (`zh-Hans`) 翻译
- [ ] 提供繁体中文 (`zh-HK`) 翻译（推荐）
- [ ] 所有用户可见文本使用 `String(localized:table:bundle:)` 并传入 `bundle: .module`
- [ ] 动态消息使用占位符 (`%@`、`%lld` 等)
- [ ] 在 Xcode 中验证本地化文件

---

## 附录

### A. 常见占位符

| 占位符 | 类型 | 示例 |
|--------|------|------|
| `%@` | 字符串 | `"Hello, %@"` → `"Hello, World"` |
| `%d` | 整数 | `"%d items"` → `"5 items"` |
| `%lld` | 长整数 | `"%lld files"` → `"100 files"` |
| `%.2f` | 浮点数 | `"%.2f MB"` → `"12.34 MB"` |

### B. 语言代码参考

| 代码 | 语言 | 地区 |
|------|------|------|
| `en` | 英语 | - |
| `zh-Hans` | 简体中文 | 中国大陆 |
| `zh-HK` | 繁体中文 | 中国香港 |
| `zh-TW` | 繁体中文 | 中国台湾 |
| `ja` | 日语 | 日本 |
| `ko` | 韩语 | 韩国 |

### C. Xcode 本地化导出

1. 在 Xcode 中选择项目
2. 选择 **Editor** → **Export Localizations**
3. 选择导出格式为 `.xcstrings`
4. 选择要导出的语言

### D. 相关文档

- [Apple Localization 文档](https://developer.apple.com/documentation/xcode/localization)
- [Swift Package Manager Resources](https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package)