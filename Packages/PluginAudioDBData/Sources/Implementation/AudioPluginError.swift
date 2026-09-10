import Foundation
import SwiftUI

private func audioErrorString(_ keyAndValue: String.LocalizationValue) -> String {
    String(localized: keyAndValue)
}

/// 音频插件的所有错误类型
/// 统一管理，提供一致的错误处理策略

// MARK: - 音频插件核心错误

public enum AudioPluginError: Error, LocalizedError {
    case hostNotConfigured
    case NoNextAsset
    case NoPrevAsset
    case NoDisk
    case initialization(reason: String)
    case diskAccess(url: URL, underlying: String)
    case configurationError(setting: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .hostNotConfigured:
            return audioErrorString("Audio plugin host configuration is incomplete")
        case .NoNextAsset:
            return audioErrorString("No next audio file")
        case .NoPrevAsset:
            return audioErrorString("No previous audio file")
        case .NoDisk:
            return audioErrorString("Unable to access disk")
        case let .initialization(reason):
            return audioErrorString("Initialization failed: \(reason)")
        case let .diskAccess(url, underlying):
            return audioErrorString("Disk access failed [\(url.lastPathComponent)]: \(underlying)")
        case let .configurationError(setting, reason):
            return audioErrorString("Configuration error [\(setting)]: \(reason)")
        }
    }

    public var failureReason: String? {
        switch self {
        case .hostNotConfigured:
            return audioErrorString("The app has not injected database and storage path configuration.")
        case .NoNextAsset:
            return audioErrorString("The current audio is the last item in the playlist.")
        case .NoPrevAsset:
            return audioErrorString("The current audio is the first item in the playlist.")
        case .NoDisk:
            return audioErrorString("The specified disk path does not exist or cannot be accessed.")
        case .initialization:
            return audioErrorString("An error occurred while initializing the app.")
        case .diskAccess:
            return audioErrorString("The specified disk location cannot be accessed.")
        case .configurationError:
            return audioErrorString("There is a problem with the app configuration.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .hostNotConfigured:
            return audioErrorString("Check the app startup flow.")
        case .NoNextAsset, .NoPrevAsset:
            return audioErrorString("Check the playlist or switch to another playback mode.")
        case .NoDisk:
            return audioErrorString("Check the disk path and access permissions.")
        case .initialization:
            return audioErrorString("Try restarting the app.")
        case .diskAccess:
            return audioErrorString("Check disk space and access permissions.")
        case .configurationError:
            return audioErrorString("Check app settings or reinstall the app.")
        }
    }
}

// MARK: - 音频记录数据库错误

public enum AudioRecordDBError: Error, LocalizedError {
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

    public var errorDescription: String? {
        switch self {
        case let .ToggleLikeError(error):
            return audioErrorString("Failed to toggle like status: \(error.localizedDescription)")
        case let .AudioNotFound(url):
            return audioErrorString("Audio not found: \(url.lastPathComponent)")
        case let .databaseOperation(operation, underlying):
            return audioErrorString("Database operation failed [\(operation)]: \(underlying)")
        case let .saveFailed(error):
            return audioErrorString("Failed to save data: \(error.localizedDescription)")
        case let .deleteFailed(error):
            return audioErrorString("Failed to delete data: \(error.localizedDescription)")
        }
    }

    public var failureReason: String? {
        switch self {
        case .ToggleLikeError:
            return audioErrorString("The database update operation failed.")
        case .AudioNotFound:
            return audioErrorString("The requested audio file does not exist.")
        case .databaseOperation:
            return audioErrorString("The database operation failed.")
        case .saveFailed:
            return audioErrorString("The data persistence operation failed.")
        case .deleteFailed:
            return audioErrorString("The data deletion operation failed.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .ToggleLikeError:
            return audioErrorString("Try again later.")
        case .AudioNotFound:
            return audioErrorString("Check whether the file exists or sync again.")
        case .databaseOperation:
            return audioErrorString("Try restarting the app or resetting the database.")
        case .saveFailed, .deleteFailed:
            return audioErrorString("Check disk space and permissions.")
        }
    }
}

// MARK: - 音频模型错误

public enum AudioModelError: Error, LocalizedError {
    case deleteFailed
    case dbNotFound
    case invalidData(String)
    case fileCorrupted(URL)

    public var errorDescription: String? {
        switch self {
        case .deleteFailed:
            return audioErrorString("Delete operation failed")
        case .dbNotFound:
            return audioErrorString("Database not found")
        case let .invalidData(reason):
            return audioErrorString("Invalid data: \(reason)")
        case let .fileCorrupted(url):
            return audioErrorString("File is corrupted: \(url.lastPathComponent)")
        }
    }

    public var failureReason: String? {
        switch self {
        case .deleteFailed:
            return audioErrorString("File system permissions are insufficient or the file is in use.")
        case .dbNotFound:
            return audioErrorString("The database connection was lost or the database file is corrupted.")
        case .invalidData:
            return audioErrorString("The data format is not as expected.")
        case .fileCorrupted:
            return audioErrorString("The audio file may be corrupted or incomplete.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .deleteFailed:
            return audioErrorString("Check file permissions or close related apps.")
        case .dbNotFound:
            return audioErrorString("Try restarting the app or syncing again.")
        case .invalidData:
            return audioErrorString("Check the data source or download again.")
        case .fileCorrupted:
            return audioErrorString("Download again or choose another audio file.")
        }
    }
}

// MARK: - 音频服务错误

public enum AudioRepoError: Error, LocalizedError {
    case fileSystemError(operation: String, path: String)
    case networkError(url: URL, underlying: String)
    case invalidState(expected: String, actual: String)
    case syncFailed(Error)
    case monitorFailed(Error)

    public var errorDescription: String? {
        switch self {
        case let .fileSystemError(operation, path):
            return audioErrorString("File system error [\(operation)]: \(path)")
        case let .networkError(url, underlying):
            return audioErrorString("Network error [\(url.absoluteString)]: \(underlying)")
        case let .invalidState(expected, actual):
            return audioErrorString("Invalid state, expected: \(expected), actual: \(actual)")
        case let .syncFailed(error):
            return audioErrorString("Sync failed: \(error.localizedDescription)")
        case let .monitorFailed(error):
            return audioErrorString("File monitoring failed: \(error.localizedDescription)")
        }
    }

    public var failureReason: String? {
        switch self {
        case .fileSystemError:
            return audioErrorString("The file system operation failed.")
        case .networkError:
            return audioErrorString("The network connection or data transfer failed.")
        case .invalidState:
            return audioErrorString("The app state does not match the expected state.")
        case .syncFailed:
            return audioErrorString("An error occurred during data sync.")
        case .monitorFailed:
            return audioErrorString("The file system monitoring service failed.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .fileSystemError:
            return audioErrorString("Check file permissions and disk status.")
        case .networkError:
            return audioErrorString("Check the network connection.")
        case .invalidState:
            return audioErrorString("Try the operation again.")
        case .syncFailed:
            return audioErrorString("Check the network connection or try again later.")
        case .monitorFailed:
            return audioErrorString("Restart the app or check system permissions.")
        }
    }
}
