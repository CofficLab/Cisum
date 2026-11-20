# MPVKit

mpv 播放内核封装包：为 ReelPod 提供基于 mpv 的播放能力（含 vendored dylibs）。

## 包信息

| 项 | 值 |
| --- | --- |
| Swift 工具链 | 5.7 |
| 支持平台 | 未声明 |
| 产品 | `MPVC`、`ReelPodMPVKit` |

## 目标

| 目标 | 类型 | 依赖包 |
| --- | --- | --- |
| `MPVC` | target | - |
| `ReelPodMPVKit` | target | MPVC, SuperLogKit |

## 依赖

| 包 | 来源 |
| --- | --- |
| SuperLogKit | 本地路径 `../SuperLogKit` |

## 目录结构

```
Sources/MPVKit/
├── MPVPlayer.swift
├── MPVVideoView.swift
```

