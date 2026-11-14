# SwiftUI 项目开发指南

本文档整合了项目的所有开发规范和最佳实践。

## 角色定义

你是一名精通 SwiftUI 开发的高级工程师，拥有 20 年的开发经验。你的任务是帮助工程师完成应用开发。

## 项目概述

Cisum 是一个用 SwiftUI 开发的音频播放器，支持本地音频播放和网络音频播放。采用插件化架构，支持 macOS 和 iOS 平台。

## 开发原则

### 第一步：理解项目

在开发任何功能前：

1. 阅读项目根目录的 README.md 和 CLAUDE.md
2. 理解插件化架构（SuperPlugin 协议）
3. 查看 Core/ 目录了解核心框架
4. 理解 MVVM + Combine 数据流

### 第二步：代码编写

**语言和框架：**

- 使用最新的 Swift 和 SwiftUI
- 遵循 Apple Human Interface Guidelines
- 使用 Combine 进行响应式编程
- 使用 SwiftData 进行本地存储
- 实现自适应布局

**代码质量：**

- 添加详细代码注释（中文）
- 使用 OSLog 进行日志记录
- 实现 SuperLog 协议
- 添加错误处理
- 避免内存泄漏

**特殊注意：**

- NSMetadataUbiquitousItemPercentDownloadedKey 返回 0-100，而非 0-1

### 第三步：遵循规范

必须遵循以下规范（详见 swiftui-standards skill）：

1. **代码组织** - 独立文件、相关目录
2. **MARK 分组** - View → Action → Setter → Event Handler → Preview
3. **SuperLog 协议** - emoji + verbose + self.t
4. **事件监听** - onXxx 扩展 + perform: 语法
5. **预览代码** - 多尺寸、条件编译

## 技术栈

**核心框架：**

- SwiftUI - UI 框架
- Combine - 响应式编程
- SwiftData - 数据持久化
- OSLog - 日志记录

**项目架构：**

- 插件系统（SuperPlugin 协议）
- MVVM + Combine
- Actor-based 并发
- Protocol-oriented design

**关键依赖：**

- MagicKit (1.2.7) - 核心工具
- MagicPlayMan - 音频播放
- MagicUI - UI 组件
- MagicAlert - 警告系统

## 插件开发

创建新插件时：

1. 在 Plugins/ 目录创建插件目录
2. 实现 SuperPlugin 协议（actor）
3. 设置 static var order 控制执行顺序
4. 实现相关视图方法（addRootView, addPosterView, addTabView 等；场景为 Provider 内置固定枚举，不再由插件注册）
5. 插件将在运行时自动发现

## 开发工作流

1. **规划阶段** - 使用 /plan 命令
2. **开发阶段** - 遵循 SwiftUI 标准规范
3. **检查阶段** - 使用 /swift-check 命令
4. **提交阶段** - 使用 /commit 命令生成 commit message

## 快速参考

### 可用命令

- `/plan` - 规划实施
- `/swift-check` - 检查代码规范
- `/commit` - 生成 commit message
- `/refactor-clean` - 重构清理
- `/learn` - 提取模式

### 可用技能

- `swiftui-standards` - SwiftUI 开发标准
- `changelog-generator` - 生成变更日志

### 可用代理

- `architect` - 软件架构
- `code-reviewer` - 代码审查
- `planner` - 规划
- `refactor-cleaner` - 重构清理

## 最佳实践

**代码质量：**

- 详细代码注释（中文）
- 适当的错误处理和日志（OSLog）
- 严格的类型检查
- 避免内存泄漏

**用户界面：**

- 自适应布局
- 遵循 HIG
- 流畅的动画
- 响应式交互

**性能优化：**

- 启动时间优化
- 内存使用优化
- 电池消耗优化

**语言偏好：**

- 使用中文编写用户可见的字符串和注释
- UI 文本、错误消息使用中文

## 参考资料

- [Apple 开发者文档](https://developer.apple.com/documentation/)
- [SwiftUI 文档](https://developer.apple.com/documentation/swiftui/)
- [Combine 框架](https://developer.apple.com/documentation/combine/)
- [SwiftData](https://developer.apple.com/documentation/swiftdata/)
