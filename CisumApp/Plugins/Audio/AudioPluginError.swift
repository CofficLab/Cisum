import Foundation
import SwiftUI

/// 音频插件的所有错误类型
/// 统一管理，提供一致的错误处理策略

// MARK: - 音频插件核心错误

enum AudioPluginError: Error, LocalizedError {
    case NoNextAsset
    case NoPrevAsset
    case NoDisk
    case initialization(reason: String)
    case diskAccess(url: URL, underlying: String)
    case configurationError(setting: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .NoNextAsset:
            return "没有下一个音频文件"
        case .NoPrevAsset:
            return "没有上一个音频文件"
        case .NoDisk:
            return "无法访问磁盘"
        case let .initialization(reason):
            return "初始化失败: \(reason)"
        case let .diskAccess(url, underlying):
            return "磁盘访问失败 [\(url.lastPathComponent)]: \(underlying)"
        case let .configurationError(setting, reason):
            return "配置错误 [\(setting)]: \(reason)"
        }
    }

    var failureReason: String? {
        switch self {
        case .NoNextAsset:
            return "当前音频是播放列表中的最后一个"
        case .NoPrevAsset:
            return "当前音频是播放列表中的第一个"
        case .NoDisk:
            return "指定的磁盘路径不存在或无法访问"
        case .initialization:
            return "应用初始化过程中发生错误"
        case .diskAccess:
            return "无法访问指定的磁盘位置"
        case .configurationError:
            return "应用配置存在问题"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .NoNextAsset, .NoPrevAsset:
            return "请检查播放列表或切换到其他播放模式"
        case .NoDisk:
            return "请检查磁盘路径和访问权限"
        case .initialization:
            return "请尝试重启应用"
        case .diskAccess:
            return "请检查磁盘空间和访问权限"
        case .configurationError:
            return "请检查应用设置或重新安装"
        }
    }
}

// MARK: - 音频记录数据库错误

enum AudioRecordDBError: Error, LocalizedError {
    /// 切换喜欢状态时发生错误
    case ToggleLikeError(Error)
    /// 未找到指定 URL 的音频
    case AudioNotFound(URL)
    /// 数据库操作失败
    case databaseOperation(operation: String, underlying: String)
    /// 数据保存失败
    case saveFailed(Error)
    /// 数据删除失败
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case let .ToggleLikeError(error):
            return "切换喜欢状态失败: \(error.localizedDescription)"
        case let .AudioNotFound(url):
            return "音频未找到: \(url.lastPathComponent)"
        case let .databaseOperation(operation, underlying):
            return "数据库操作失败 [\(operation)]: \(underlying)"
        case let .saveFailed(error):
            return "数据保存失败: \(error.localizedDescription)"
        case let .deleteFailed(error):
            return "数据删除失败: \(error.localizedDescription)"
        }
    }

    var failureReason: String? {
        switch self {
        case .ToggleLikeError:
            return "数据库更新操作执行失败"
        case .AudioNotFound:
            return "请求的音频文件不存在"
        case .databaseOperation:
            return "数据库操作执行失败"
        case .saveFailed:
            return "数据持久化操作失败"
        case .deleteFailed:
            return "数据删除操作失败"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .ToggleLikeError:
            return "请稍后重试"
        case .AudioNotFound:
            return "请检查文件是否存在或重新同步"
        case .databaseOperation:
            return "请尝试重启应用或重置数据库"
        case .saveFailed, .deleteFailed:
            return "请检查磁盘空间和权限"
        }
    }
}

// MARK: - 音频模型错误

enum AudioModelError: Error, LocalizedError {
    case deleteFailed
    case dbNotFound
    case invalidData(String)
    case fileCorrupted(URL)

    var errorDescription: String? {
        switch self {
        case .deleteFailed:
            return "删除操作失败"
        case .dbNotFound:
            return "数据库未找到"
        case let .invalidData(reason):
            return "数据无效: \(reason)"
        case let .fileCorrupted(url):
            return "文件损坏: \(url.lastPathComponent)"
        }
    }

    var failureReason: String? {
        switch self {
        case .deleteFailed:
            return "文件系统权限不足或文件被占用"
        case .dbNotFound:
            return "数据库连接丢失或数据库文件损坏"
        case .invalidData:
            return "数据格式不符合预期"
        case .fileCorrupted:
            return "音频文件可能已损坏或不完整"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .deleteFailed:
            return "请检查文件权限或关闭相关应用"
        case .dbNotFound:
            return "请尝试重启应用或重新同步"
        case .invalidData:
            return "请检查数据源或重新下载"
        case .fileCorrupted:
            return "请重新下载或选择其他音频文件"
        }
    }
}

// MARK: - 音频服务错误

enum AudioRepoError: Error, LocalizedError {
    case fileSystemError(operation: String, path: String)
    case networkError(url: URL, underlying: String)
    case invalidState(expected: String, actual: String)
    case syncFailed(Error)
    case monitorFailed(Error)

    var errorDescription: String? {
        switch self {
        case let .fileSystemError(operation, path):
            return "文件系统错误 [\(operation)]: \(path)"
        case let .networkError(url, underlying):
            return "网络错误 [\(url.absoluteString)]: \(underlying)"
        case let .invalidState(expected, actual):
            return "状态无效，期望: \(expected)，实际: \(actual)"
        case let .syncFailed(error):
            return "同步失败: \(error.localizedDescription)"
        case let .monitorFailed(error):
            return "文件监控失败: \(error.localizedDescription)"
        }
    }

    var failureReason: String? {
        switch self {
        case .fileSystemError:
            return "文件系统操作失败"
        case .networkError:
            return "网络连接或数据传输失败"
        case .invalidState:
            return "应用状态与预期不符"
        case .syncFailed:
            return "数据同步过程中发生错误"
        case .monitorFailed:
            return "文件系统监控服务失败"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileSystemError:
            return "请检查文件权限和磁盘状态"
        case .networkError:
            return "请检查网络连接"
        case .invalidState:
            return "请尝试重新操作"
        case .syncFailed:
            return "请检查网络连接或稍后重试"
        case .monitorFailed:
            return "请重启应用或检查系统权限"
        }
    }
}

// MARK: Preview

#Preview("App") {
    ContentView()
        .inRootView()
        .withDebugBar()
}
