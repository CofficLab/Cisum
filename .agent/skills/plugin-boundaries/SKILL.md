---
name: plugin-boundaries
description: 检查并修复 Cisum 插件/Provider 分层边界违规（插件互依赖、环境注入、Provider 纯净性、Capabilities 边界）。
---

# Plugin Boundaries
# 插件边界检查

Cisum 的插件/Provider 分层是靠一条 zsh 脚本（`Scripts/check-plugin-boundaries.sh`，已移除）做 CI 级校验的。
本 Skill 把那条脚本的规则模型、可执行扫描命令、违规修复手册完整接管过来——**任何涉及新增/修改插件包、
调整依赖、引入 Environment 注入的场景，都应按本 Skill 自查后再交付。**

---

## 何时使用

- 新增 `Packages/Plugin*` 或 `Packages/Provider*` 包，或修改其 `Package.swift` 依赖
- 在插件里新增 `import`、环境注入（`@EnvironmentObject` / `@Environment(\.x)`）
- Provider 包里引入存储、UI、SwiftData 等基础设施
- 重构播放/音频状态传递链路（`MagicPlayMan`、`AudioRepo` 等）
- 交付前自检、CI 失败排查

---

## 总体原则

| 方向 | 规则 |
|------|------|
| 插件 ↔ 插件 | **禁止任何直接依赖**。插件之间只能通过 `Provider*` / `Kit*` / `Factory*` 通信 |
| 业务层 ↔ 环境 | **禁止隐式环境注入**。业务依赖必须走显式的 provider / plugin 构造参数 |
| Provider ↔ 实现 | Provider 只声明协议与数据，不碰存储、UI、Repository、全局通知 |
| 消费方 ↔ 具体实现 | 消费方不得使用 `AudioPluginHost` / `AudioRepo` 等具体宿主或仓储 |
| UI ↔ 播放引擎 | UI / ProviderPlayback 层不得依赖 `MagicPlayMan` 具体状态 |

---

## 规则 1：插件之间不得互相依赖（三重检查）

一个插件依赖另一个插件，可能以三种形态出现，**三种都要堵**：

1. 源码 `import PluginXXX`
2. `Package.swift` 里 `.product(name: "PluginXXX", ...)`
3. `Package.swift` 里 `.package(path: "../PluginXXX")`

```bash
# 1) 源码 import
rg -n '^import Plugin[A-Z]' Packages/Plugin*/Sources --glob '*.swift' \
  --glob '!**/Tests/**' --glob '!**/.build/**'

# 2) target 依赖别的插件 product
rg -n '\.product\(name: "Plugin[A-Z]' Packages/Plugin*/Package.swift

# 3) 包级依赖别的插件包
rg -n '\.package\((name: "[^"]+", )?path: "\.\./Plugin[A-Z]' Packages/Plugin*/Package.swift
```

**修复方向**：把被复用的能力下沉到 `Provider*`（数据/契约）或 `Kit*`（纯工具）包，双方各加一个依赖。

---

## 规则 2：业务依赖必须显式传入，禁止环境注入

适用范围：`Packages/Plugin*/Sources`、`Packages/Provider*/Sources`、
`Packages/FactoryCisum/Sources`、`Packages/CisumUIComponents/Sources`。

```bash
rg -n '@EnvironmentObject|\.environmentObject\(|EnvironmentKey|EnvironmentValues' \
  Packages/Plugin*/Sources Packages/Provider*/Sources \
  Packages/FactoryCisum/Sources Packages/CisumUIComponents/Sources \
  --glob '*.swift' --glob '!**/Tests/**' --glob '!**/.build/**'
```

具名 Environment key 黑名单（出现即违规，代表某条业务依赖被偷塞进环境）：

```
demoMode  appIsImporting  showAudioDBViewAction
pluginThemes  currentPluginThemeId  selectPluginThemeAction  resetSettingsAction
sceneProviding  posterDismissAction  toastProviding
audioDBDependencies  bookDBDependencies  bookDBImportAction  pluginStorageDependencies
```

```bash
rg -n '@Environment\(\.(demoMode|appIsImporting|showAudioDBViewAction|pluginThemes|currentPluginThemeId|selectPluginThemeAction|resetSettingsAction|sceneProviding|posterDismissAction|toastProviding|audioDBDependencies|bookDBDependencies|bookDBImportAction|pluginStorageDependencies)\)' \
  Packages/Plugin*/Sources Packages/Provider*/Sources \
  Packages/FactoryCisum/Sources Packages/CisumUIComponents/Sources \
  --glob '*.swift' --glob '!**/Tests/**' --glob '!**/.build/**'
```

> **扫描范围必须是「存在的目录」。** 原脚本硬编码了 `Packages/CisumUIComponents/Sources`，
> 该包在当前仓库已不存在，`rg` 会报 `No such file or directory` 并污染输出。
> 每次扫描前先确认目录存在，或只列出 `ls Packages` 中真实存在的包名。

**修复方向**：改为在插件入口组装（`onBoot(kernel:)`）解析 Provider，构造时注入 View / ViewModel。
若跨插件 boot 顺序不确定，用**惰性解析闭包**而不是启动时的快照（见下节）。

---

## 规则 3：Audio Provider 保持纯净

范围：`Packages/ProviderAudioLibrary/Sources`、`Packages/ProviderAudioLike/Sources`。

**3.1 不得 import 实现层或 UI 层**

```bash
rg -n '^import (SwiftData|SwiftUI|OSLog|ProviderStorage|CisumUIComponents|MagicKit)' \
  Packages/ProviderAudioLibrary/Sources Packages/ProviderAudioLike/Sources --glob '*.swift'
```

**3.2 不得出现具体存储 / 仓储 / 全局事件**

```bash
rg -n '^[^/]*(FileManager|UserDefaults|NotificationCenter|AudioDB|AudioRepo|AudioLikeRepo)' \
  Packages/ProviderAudioLibrary/Sources Packages/ProviderAudioLike/Sources \
  --glob '*.swift' --glob '!**/README.md'
```

注意正则前面的 `^[^/]*`：意图是排除**注释行**里对这些词的说明性提及，
因此不要"优化"掉它，也不要改成更宽松的匹配。

**修复方向**：存储与 IO 下沉到 `PluginAudioDBData` / `PluginStorage`；Provider 只暴露查询与变更意图。

---

## 规则 4：消费方不得触碰具体宿主与仓储

范围：`PluginAudio`、`PluginAudioCopy`、`PluginAudioDBView`、`PluginAudioPlayMode`、
`PluginAudioProgress`、`PluginAudioSettings`、`PluginAudioWidgetControl`。

```bash
rg -n 'AudioPluginHost|getAudioRepoAsync|getAudioRepo\(|(^|[^A-Za-z])AudioRepo\(' \
  Packages/PluginAudio/Sources Packages/PluginAudioCopy/Sources Packages/PluginAudioDBView/Sources \
  Packages/PluginAudioPlayMode/Sources Packages/PluginAudioProgress/Sources \
  Packages/PluginAudioSettings/Sources Packages/PluginAudioWidgetControl/Sources \
  --glob '*.swift' --glob '!**/Tests/**' --glob '!**/.build/**'
```

**修复方向**：消费方通过 `Capabilities/` 下的窄能力协议访问数据，不接触仓储类型。

---

## 规则 5：UI / 播放 Provider 不得依赖 MagicPlayMan

范围：`Packages/FactoryCisum/Sources/FactoryCisum/Views`、`Packages/ProviderControlView/Sources`、
`Packages/ProviderPlayback/Sources`。

```bash
rg -n '@EnvironmentObject[^\n]*MagicPlayMan|as\?\s*MagicPlayMan|^import MagicPlayMan' \
  Packages/FactoryCisum/Sources/FactoryCisum/Views Packages/ProviderControlView/Sources \
  Packages/ProviderPlayback/Sources --glob '*.swift'
```

**修复方向**：播放状态通过 `ProviderPlayback` 的协议接口读取；UI 只消费协议，不接触引擎实例。

---

## 附加检查：Capabilities 边界（View/ViewModel 不得直接持有 Provider）

这是项目《插件 Capabilities 能力边界规范》要求的，原脚本未覆盖，本次一并纳入。

```bash
cd Packages && for p in Plugin*/; do n=$(basename $p); [ -d "$p/Sources" ] || continue
  files=$(grep -rlE "any [A-Z][A-Za-z]*Providing" "$p/Sources" --include="*.swift" 2>/dev/null \
    | grep -v "/Capabilities/" | grep -vE "Plugin\.swift$")
  c=$(echo "$files" | grep -c .)
  [ "$c" != "0" ] && { echo "-- $n"; echo "$files" | sed "s|$p/Sources/||"; }
done
```

> **必须用宽模式 `any XxxProviding`，不要用 `(any ...`。** 带括号的窄模式会漏掉
> `init(provider: any StorageProviding)` 这类无括号签名——首次扫描因此漏掉了 6 个插件。

**当前允许的残留**（每处都应在代码注释里写明豁免理由）：

| 位置 | 理由 |
|------|------|
| `Providers/`、`Services/` 下的 Provider 实现文件 | 生产目录，含其基础设施依赖 |
| 插件入口 `*Plugin.swift` / `*Manager.swift` | 组装层，可直接 resolve Provider |
| `AudioStorageDiagnosticsFactory`（PluginAudioDBView） | 一次性诊断快照，不订阅不持有 |
| `AudioProgressViewModel` 的 `audioLike` 闭包 | 恢复进度时一次性读取 |
| `CisumRootLayoutView`（PluginRootView） | 组装层 View，resolve 后立即包成 Adapter |
| `PluginPluginManager.swift`、`PluginScene` | 自身即 Provider 生产方 / 入口 |

**新建命中项时**：把消费收敛到 `Sources/Capabilities/`（或 `Sources/<Package>/Capabilities/`）的
`<前缀><Domain>Capability` + `Adapter`；Adapter 持有 Provider 用 `weak`；
**插件入口必须强持有 Adapter**，否则临时创建的 Adapter 会立即释放导致能力静默失效。

---

## 标准执行流程

1. `cd` 到仓库根目录
2. 按规则 1 → 5 依次执行扫描命令（先确认扫描目录存在）
3. 执行 Capabilities 附加检查
4. 全部无输出即为通过
5. 修复违规后，重跑受影响的包的测试：

```bash
cd Packages && for p in Plugin*/; do [ -d "$p/Tests" ] || continue
  printf "%-26s " "$(basename $p)"; (cd $p && swift test 2>&1 | grep -E "✘|error:|Test run with" | tail -1)
done
```

（一次全量约 4 分钟。）

---

## 交付检查清单

- [ ] 插件之间无 `import` / `.product` / `.package` 交叉依赖
- [ ] 业务层无 `@EnvironmentObject` / `.environmentObject(` / `EnvironmentKey` / `EnvironmentValues`
- [ ] 无具名业务 Environment key 被 `@Environment(\.xxx)` 读取
- [ ] Audio Provider 无实现层/UI import，无 `FileManager`/`UserDefaults`/`NotificationCenter`/仓储直接使用
- [ ] 消费方无 `AudioPluginHost` / `getAudioRepo` / `AudioRepo(`
- [ ] FactoryCisum Views、ProviderControlView、ProviderPlayback 无 `MagicPlayMan` 依赖
- [ ] View / ViewModel / Observer 不直接持有 `any *Providing`（或已有豁免注释）
- [ ] 跨插件惰性解析场景用闭包而非快照（避免 Provider 注册晚于视图请求导致永久失效）
- [ ] 扫描命令引用的目录在当前仓库真实存在

---

## 常见违规与修法速查

| 违规现象 | 正确修法 |
|---------|---------|
| 插件 B 里 `import PluginA` | 抽公共能力到 `Provider*`/`Kit*` 包，B 与 A 各自依赖它 |
| `.package(path: "../PluginX")` | 换成对 `Provider*` 的本地 path 依赖 |
| View 里 `@EnvironmentObject var toast: ToastProviding` | 入口组装时把 Toast 能力注入 ViewModel |
| Provider 里 `import SwiftData` 后直接开 `ModelContext` | IO 移到 `PluginAudioDBData`，Provider 只暴露意图 |
| 消费方 `AudioRepo()` 查数据 | 建 `AudioLibraryCapability`，Adapter 持 `weak` Provider |
| `Adapter(provider:)` 在入口临时创建后注入 | 入口用属性强持有 Adapter，shutdown 时释放 |

---

## 相关规范

- `Scripts/check-plugin-boundaries.sh`（已由本 Skill 取代）
- `.agent/rules/plugin-capabilities.md` — Capabilities 能力边界规范
- `.agent/rules/plugin-package-structure.md` — 插件包目录结构规范
