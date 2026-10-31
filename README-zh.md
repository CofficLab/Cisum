# Cisum

[![English](https://img.shields.io/badge/English-violet)](README.md) [![简体中文](https://img.shields.io/badge/中文文档-gray)](README-zh.md) [![Coffic](https://img.shields.io/badge/Coffic-green)](https://coffic.cn) [![Maintainer](https://img.shields.io/badge/Maintainer-blue)](https://github.com/nookery) [![AppStore](https://img.shields.io/badge/AppStore-red)](https://apps.apple.com/cn/app/cisum/id6466401036)

![Cisum for iPhone and Mac](./docs/readme-preview-zh.svg)

## 关于

[产品介绍](https://coffic.cn/cisum)

[App Store](https://apps.apple.com/cn/app/cisum/id6466401036)

## 动机

你在被这些东西毒害吗？

- 开屏广告
- 抖一抖跳转
- 花样繁多的弹窗
- 10 秒启动时间
- 眼花缭乱的功能

让软件更纯粹一些，我们决定自己做一个。

## 架构

Cisum 是一款基于插件的 SwiftUI 音频播放器。代码按职责拆分到 `Packages/` 下相互独立的
Swift Package，分为四种角色：

```text
FactoryCisum
  ├── Plugin*  ── consumes ──> Provider*
  ├── Provider* ── uses ─────> Kit*
  └── Kit*
```

| 角色 | 职责 |
|------|------|
| `Kit*` | 不属于单一功能的可复用基础设施（播放原语、UI 组件、事件观察） |
| `Provider*` | 面向 App 的契约、领域模型、事件与观察句柄 |
| `Plugin*` | 每个包实现一个功能，通过 Provider 契约消费其他功能 |
| `FactoryCisum` | 唯一的组装层，负责装配各 Provider 与插件 |

插件之间不直接依赖——共享能力通过 `Provider*`（数据与契约）或 `Kit*`（纯工具）包流转。

## 开发

### 环境要求

| 工具 | 版本 |
|------|------|
| macOS | 14.0 及以上 |
| Xcode | 27.2 及以上 |
| Swift | 6.0 及以上 |

### 构建与运行

```bash
git clone https://github.com/CofficLab/Cisum.git
cd Cisum

xcodebuild -list -project Cisum.xcodeproj
xcodebuild -project Cisum.xcodeproj -scheme Cisum -destination 'platform=macOS' build
```

### 构建与测试单个包

每个包都是独立的 Swift Package，日常开发可以走更快的内循环：

```bash
cd Packages/PluginAudioDBView
swift build
swift test
```

### 运行测试

```bash
# 包级单元测试
cd Packages && for p in Plugin*/; do [ -d "$p/Tests" ] || continue
  printf "%-26s " "$(basename $p)"; (cd $p && swift test 2>&1 | grep -E "✘|error:|Test run with" | tail -1)
done

# App 级单元测试与 UI 测试
xcodebuild -project Cisum.xcodeproj -scheme Cisum -destination 'platform=macOS' test
```

### 代码覆盖率

```bash
scripts/collect-coverage.sh              # 全部有源码的包
scripts/collect-coverage.sh MagicKit     # 指定单个包
```

报告输出到 `temp/coverage/report.md`。

## 参与贡献

欢迎贡献代码。请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)，其中包含开发环境搭建、架构边界规则、
代码规范、国际化与日志约定、提交信息格式以及 Pull Request 流程。

## 我们的其他作品

- [macOS 联网控制](https://coffic.cn/zh-cn/products/travelmode)
- [基于 Git 的项目管理工具](https://coffic.cn/zh-cn/products/gitok)
