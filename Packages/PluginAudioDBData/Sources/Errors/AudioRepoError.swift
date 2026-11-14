import Foundation

// MARK: - 音频仓库错误

/// 音频仓库（文件系统、网络、同步、监控）相关错误。
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
