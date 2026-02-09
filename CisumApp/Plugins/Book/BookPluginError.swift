import Foundation
import SwiftUI

// MARK: - Book Plugin Errors

enum BookPluginError: Error, LocalizedError {
    case NoNextAsset
    case NoPrevAsset
    case NoDisk
    case DiskNotFound
    case initialization(reason: String)

    var errorDescription: String? {
        switch self {
        case .NoNextAsset:
            return "没有下一个章节/文件"
        case .NoPrevAsset:
            return "没有上一个章节/文件"
        case .NoDisk:
            return "无法访问磁盘"
        case .DiskNotFound:
            return "磁盘未找到"
        case .initialization(let reason):
            return "初始化失败: \(reason)"
        }
    }

    var failureReason: String? {
        switch self {
        case .NoNextAsset:
            return "当前已是最后一个条目"
        case .NoPrevAsset:
            return "当前已是第一个条目"
        case .NoDisk:
            return "指定的磁盘路径不存在或无法访问"
        case .DiskNotFound:
            return "指定的磁盘路径不存在或无法访问"
        case .initialization:
            return "插件初始化过程中发生错误"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .NoNextAsset, .NoPrevAsset:
            return "请检查播放顺序或选择其他条目"
        case .NoDisk:
            return "请检查磁盘权限与路径设置"
        case .DiskNotFound:
            return "请检查磁盘权限与路径设置"
        case .initialization:
            return "请尝试重启应用或检查设置"
        }
    }
}

// MARK: - Preview

#if os(macOS)
    #Preview("App - Large") {
        ContentView()
    .inRootView()
            .frame(width: 600, height: 1000)
    }

    #Preview("App - Small") {
        ContentView()
    .inRootView()
            .frame(width: 500, height: 800)
    }
#endif

#if os(iOS)
    #Preview("iPhone") {
        ContentView()
    .inRootView()
    }
#endif


