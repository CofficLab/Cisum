---
name: i18n-translate
description: 管理 iOS/macOS 应用的 Localizable.xcstrings 本地化翻译文件。自动清理过期条目、检测缺失翻译、添加简繁体中文翻译。当用户需要处理翻译、补充缺失的 zh-Hans/zh-HK 翻译、或清理 Localizable.xcstrings 文件时使用此 skill。
---

# iOS/macOS 本地化翻译管理

管理 `Localizable.xcstrings` 文件的中文翻译，支持简体中文 (zh-Hans) 和繁体中文 (zh-HK)。

## 工作流程

处理翻译请求时，按以下顺序执行：

### 1. 清理过期条目

```bash
python3 scripts/clean_stale.py Localizable.xcstrings
```

删除所有 `extractionState` 为 `stale` 的条目。

### 2. 检查缺失翻译

```bash
python3 scripts/check_missing.py Localizable.xcstrings
```

输出缺失的 zh-Hans 和 zh-HK 翻译统计。

### 3. 添加翻译

```bash
python3 scripts/add_translation.py Localizable.xcstrings "Key" "简体中文翻译" "繁體中文翻譯"
```

- `Key`: 条目的 key
- `zh-Hans`: 简体中文翻译（必需）
- `zh-HK`: 繁体中文翻译（可选，未提供时自动转换）

### 4. 验证文件

```bash
python3 scripts/validate.py Localizable.xcstrings
```

验证 JSON 格式正确性并统计翻译完成度。

## 翻译原则

- **占位符保持不变**: `%@`, `%lld`, `%1$@`, `%d` 等格式化占位符必须原样保留
- **技术术语**: API, SQLite, Host 等专有名词可保持英文
- **UI 文本**: 简洁明了，符合 macOS/iOS 应用习惯
- **简繁转换**: `add_translation.py` 包含常见词汇的简繁转换映射

## 使用示例

```
用户: 检查 Localizable.xcstrings 缺少的翻译
→ 运行 check_missing.py

用户: 为 "Copy" 添加翻译
→ 运行 add_translation.py Localizable.xcstrings "Copy" "拷贝" "拷貝"

用户: 清理过期的翻译条目
→ 运行 clean_stale.py
```

## 注意事项

- 所有操作会直接修改 `Localizable.xcstrings` 文件
- 修改前建议先备份文件
- JSON 缩进使用 2 个空格
- 编码必须是 UTF-8
